"""
Thiruvananthapuram Urban Flood Prediction API  v4.2
Phase 1: LightGBM  →  rainfall + place  →  risk label + probabilities
Phase 2: GNN       →  5-feature spatial refinement (3-class)

v4.2 FIX — GNN input mismatch (root cause of LightGBM=Medium, GNN=High):
─────────────────────────────────────────────────────────────────────────
PROBLEM:
  The GNN was trained (train_gnn.py) using LABEL_BASE scores:
      Low=0.13,  Medium=0.50,  High=0.82
  as the phase1_risk node feature.

  But main.py was feeding prob_high (the raw LightGBM High-class probability)
  as phase1_risk at inference time.

  When LightGBM predicts Medium, prob_high is typically 0.10–0.25.
  This is indistinguishable from the Low training range (centred at 0.13).
  The GNN therefore sees:
      phase1_risk ≈ 0.15  (looks like Low)
      flood_freq  = 0.485 (historically floods a lot)
  and resolves this contradiction by outputting High.
  Result: LightGBM=Medium → GNN=High.  This is wrong.

FIX:
  Convert the LightGBM predicted label back to a canonical score that
  exactly matches the training distribution:
      Low    → 0.13
      Medium → 0.50
      High   → 0.82
  Then blend in a small probability nudge so areas at the boundary get
  a slight boost toward the next class, preserving some gradient signal.

  Final formula:
      phase1_risk = label_base_score + 0.08 * (prob_high - label_base_score)

  This keeps the value centred on the training anchor while allowing a
  small continuous shift from the actual probability.
  The GNN now sees the same input distribution it was trained on.
"""

import os, sys, json

os.environ["OMP_NUM_THREADS"] = "1"
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import torch
import torch.nn.functional as F
from torch_geometric.data import Data
from torch_geometric.nn import GCNConv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import joblib
import pandas as pd

# ─────────────────────────────────────────────────────────────────
# App
# ─────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Trivandrum Flood Prediction API",
    description="Phase-1: LightGBM | Phase-2: GNN (5-feature, 3-class, label-anchored input)",
    version="4.2.0",
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True,
    allow_methods=["*"], allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────────
# Phase-1: LightGBM
# ─────────────────────────────────────────────────────────────────
lgbm_model    = joblib.load("rain_risk_model.pkl")
lgbm_model.set_params(n_jobs=1)  # Prevent LightGBM segmentation fault on macOS
place_mapping = joblib.load("place_mapping.pkl")
place_to_code = {v: k for k, v in place_mapping.items()}

LABEL_MAP = {0: "Low", 1: "Medium", 2: "High"}

# These MUST match train_gnn.py LABEL_BASE exactly
LABEL_BASE = {"Low": 0.13, "Medium": 0.50, "High": 0.82}

def normalise_label(raw) -> str:
    if isinstance(raw, (int, float)):
        return LABEL_MAP[int(raw)]
    s = str(raw).strip().capitalize()
    if s not in ("Low", "Medium", "High"):
        raise ValueError(f"Unexpected label: {raw!r}")
    return s

def label_to_gnn_score(label: str, prob_high: float) -> float:
    """
    Convert LightGBM predicted label to a GNN-compatible phase1_risk score.

    Uses the same anchor values as LABEL_BASE in train_gnn.py, then applies
    a small blend (8%) from the raw prob_high so the score is not completely
    discrete. This prevents GNN input distribution mismatch.

    Examples:
        Low,    prob_high=0.05  ->  0.13 + 0.08*(0.05-0.13) = 0.123
        Medium, prob_high=0.20  ->  0.50 + 0.08*(0.20-0.50) = 0.476
        High,   prob_high=0.78  ->  0.82 + 0.08*(0.78-0.82) = 0.817
    """
    base  = LABEL_BASE[label]
    score = base + 0.08 * (prob_high - base)
    return round(float(score), 4)

# ─────────────────────────────────────────────────────────────────
# Phase-2: GCN — 5-feature, 3-class
# ─────────────────────────────────────────────────────────────────
class GCN(torch.nn.Module):
    """
    Input : 5 features — [lat_norm, lon_norm, flood_freq, high_freq, phase1_risk]
    Output: 3 logits   — Low / Medium / High
    Layers: 5 → 64 → 32 → 16 → 3
    """
    def __init__(self):
        super().__init__()
        self.conv1 = GCNConv(5, 64)
        self.conv2 = GCNConv(64, 32)
        self.conv3 = GCNConv(32, 16)
        self.conv4 = GCNConv(16,  3)
        self.bn1   = torch.nn.BatchNorm1d(64)
        self.bn2   = torch.nn.BatchNorm1d(32)

    def forward(self, data):
        x, ei = data.x, data.edge_index
        x = F.relu(self.bn1(self.conv1(x, ei)))
        x = F.dropout(x, p=0.15, training=self.training)
        x = F.relu(self.bn2(self.conv2(x, ei)))
        x = F.dropout(x, p=0.10, training=self.training)
        x = F.relu(self.conv3(x, ei))
        x = self.conv4(x, ei)
        return x

# ── Load static node features ─────────────────────────────────────
GNN_FEATURES_FILE = "gnn_node_features.json"

if not os.path.exists(GNN_FEATURES_FILE):
    print(f"⚠️  {GNN_FEATURES_FILE} not found — building from CSVs")
    _areas = pd.read_csv("areas.csv")
    _df    = pd.read_csv("risk_dataset.csv")
    _df["place"] = _df["place"].replace({"Vattiyurkkavu": "Vattiyoorkavu"})
    _lm, _ls = _areas["lat"].mean(), _areas["lat"].std()
    _om, _os = _areas["lon"].mean(), _areas["lon"].std()
    _areas_places = _areas["place"].tolist()
    _place_static = {}
    for p in _areas_places:
        row = _areas[_areas["place"] == p].iloc[0]
        sub = _df[_df["place"] == p]["risk_label"]
        ff  = float((sub != "Low").mean()) if len(sub) > 0 else 0.20
        hf  = float((sub == "High").mean()) if len(sub) > 0 else 0.10
        _place_static[p] = [
            float((row["lat"] - _lm) / (_ls + 1e-8)),
            float((row["lon"] - _om) / (_os + 1e-8)),
            round(ff, 4), round(hf, 4),
        ]
    _meta = {"place_static_feats": _place_static, "areas_order": _areas_places}
else:
    with open(GNN_FEATURES_FILE) as f:
        _meta = json.load(f)

AREAS_ORDER  = _meta["areas_order"]
PLACE_STATIC = _meta["place_static_feats"]

# ── Load graph edges ──────────────────────────────────────────────
edges_df   = pd.read_csv("edges.csv")
_edge_raw  = torch.tensor(edges_df[["source", "target"]].values.T, dtype=torch.long)
EDGE_INDEX = torch.cat([_edge_raw, _edge_raw.flip(0)], dim=1)

# ── Load GNN weights with shape validation ────────────────────────
gnn_model     = GCN()
gnn_ready     = False
gnn_error_msg = ""

try:
    state = torch.load("gnn_model.pth", map_location="cpu")
    gnn_model.load_state_dict(state)
    gnn_model.eval()
    with torch.no_grad():
        _out = gnn_model(Data(x=torch.randn(14, 5), edge_index=EDGE_INDEX))
    assert _out.shape == (14, 3), f"Expected [14,3], got {list(_out.shape)}"
    gnn_ready = True
    print("✅ GNN loaded — 5-feature input, 3-class output")
except Exception as e:
    gnn_error_msg = str(e)
    print(f"⚠️  GNN load failed: {e}")
    print("   Run:  python bootstrap_gnn.py  then  python train_gnn.py")

# ── In-memory phase1_risk store (label-anchored scores) ──────────
# Default = LABEL_BASE["Low"] so GNN starts with a consistent Low baseline
_phase1_store: dict = {p: LABEL_BASE["Low"] for p in AREAS_ORDER}

def _build_gnn_tensor() -> torch.Tensor:
    """Build [14, 5] feature tensor. Uses label-anchored phase1_risk values."""
    rows = []
    for place in AREAS_ORDER:
        static = PLACE_STATIC[place]          # [lat_n, lon_n, flood_freq, high_freq]
        p1r    = float(_phase1_store.get(place, LABEL_BASE["Low"]))
        rows.append(static + [p1r])
    return torch.tensor(rows, dtype=torch.float)

# ─────────────────────────────────────────────────────────────────
# Request schemas
# ─────────────────────────────────────────────────────────────────
class PredictRequest(BaseModel):
    place: str
    rainfall_mm: float

class GNNRequest(BaseModel):
    place: str

class FullPredictRequest(BaseModel):
    place: str
    rainfall_mm: float

# ─────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {
        "status":       "✅ Trivandrum Flood API v4.2 running",
        "gnn_ready":    gnn_ready,
        "fix_applied":  "label-anchored phase1_risk — GNN input matches training distribution",
        "gnn_note":     gnn_error_msg if not gnn_ready else "OK",
        "endpoints": {
            "phase1":  "POST /predict/",
            "phase2":  "POST /predict-gnn/",
            "full":    "POST /predict-full/",
            "places":  "GET  /places/",
            "debug":   "GET  /debug/areas/",
        },
    }

@app.get("/places/")
def list_places():
    return {"places": AREAS_ORDER}

@app.get("/debug/areas/")
def debug_areas():
    """
    Shows the live label-anchored phase1_risk score for all 14 areas.
    Low ≈ 0.13,  Medium ≈ 0.50,  High ≈ 0.82
    """
    rows = []
    for place in AREAS_ORDER:
        score = _phase1_store.get(place, LABEL_BASE["Low"])
        # Reverse-map score back to approximate label for display
        if score >= 0.65:
            approx = "High"
        elif score >= 0.30:
            approx = "Medium"
        else:
            approx = "Low"
        rows.append({
            "place":          place,
            "phase1_risk":    round(score, 4),
            "approx_label":   approx,
        })
    return {
        "areas":    rows,
        "gnn_ready": gnn_ready,
        "note":     "phase1_risk is label-anchored: Low≈0.13, Medium≈0.50, High≈0.82",
    }

# ── POST /predict/ — Phase 1 ──────────────────────────────────────
@app.post("/predict/")
def predict_phase1(request: PredictRequest):
    place    = request.place
    rainfall = request.rainfall_mm

    code = place_to_code.get(place)
    if code is None:
        raise HTTPException(
            status_code=404,
            detail=f"Unknown place '{place}'. Valid: {list(place_to_code.keys())}"
        )

    X          = pd.DataFrame([[rainfall, code]], columns=["rainfall_mm", "place_code"])
    raw_pred   = lgbm_model.predict(X)[0]
    pred_label = normalise_label(raw_pred)
    pred_probs = lgbm_model.predict_proba(X)[0]
    classes    = list(lgbm_model.classes_)
    prob_dict  = {str(c).capitalize(): float(p) for c, p in zip(classes, pred_probs)}

    prob_low    = prob_dict.get("Low",    prob_dict.get("0", 0.0))
    prob_medium = prob_dict.get("Medium", prob_dict.get("1", 0.0))
    prob_high   = prob_dict.get("High",   prob_dict.get("2", 0.0))

    # KEY FIX: use label-anchored score instead of raw prob_high
    # This ensures GNN sees values in the same range it was trained on
    gnn_input_score = label_to_gnn_score(pred_label, prob_high)

    # Update in-memory store with the label-anchored score
    _phase1_store[place] = gnn_input_score

    # Persist to CSV for debugging
    try:
        areas_df = pd.read_csv("areas.csv")
        if "phase1_risk" not in areas_df.columns:
            areas_df["phase1_risk"] = LABEL_BASE["Low"]
        areas_df.loc[areas_df["place"] == place, "phase1_risk"] = gnn_input_score
        areas_df.to_csv("areas.csv", index=False)
    except Exception as e:
        print(f"⚠️  CSV write error: {e}")

    return {
        "place":                place,
        "rainfall_mm":          rainfall,
        "predicted_risk_label": pred_label,
        "phase1_risk_score":    gnn_input_score,           # label-anchored score (matches GNN training)
        "prob_high_raw":        round(prob_high, 4),       # raw LightGBM High-class probability (display only)
        "gnn_input_score":      gnn_input_score,           # what GNN actually receives
        "probabilities": {
            "Low":    round(prob_low,    4),
            "Medium": round(prob_medium, 4),
            "High":   round(prob_high,   4),
        },
    }

# ── POST /predict-gnn/ — Phase 2 ─────────────────────────────────
@app.post("/predict-gnn/")
def predict_phase2(request: GNNRequest):
    place = request.place
    if place not in AREAS_ORDER:
        raise HTTPException(
            status_code=404,
            detail=f"Place '{place}' not found. Valid: {AREAS_ORDER}"
        )

    if not gnn_ready:
        # Fallback: use Phase 1 label from store
        score = _phase1_store.get(place, LABEL_BASE["Low"])
        if score >= 0.65:
            fallback_label = "High"
            fallback_int   = 2
        elif score >= 0.30:
            fallback_label = "Medium"
            fallback_int   = 1
        else:
            fallback_label = "Low"
            fallback_int   = 0
        return {
            "place":             place,
            "phase1_risk_used":  round(score, 4),
            "gnn_refined_label": fallback_int,
            "risk_level":        fallback_label,
            "gnn_probabilities": {"Low": 0.0, "Medium": 0.0, "High": 0.0},
            "note":              f"⚠️ GNN not ready. Run bootstrap_gnn.py then train_gnn.py.",
        }

    x    = _build_gnn_tensor()
    data = Data(x=x, edge_index=EDGE_INDEX)

    with torch.no_grad():
        logits = gnn_model(data)
        probs  = F.softmax(logits, dim=1)
        preds  = logits.argmax(dim=1)

    area_id       = AREAS_ORDER.index(place)
    gnn_label_int = int(preds[area_id].item())
    gnn_probs     = probs[area_id].tolist()
    phase1_used   = _phase1_store.get(place, LABEL_BASE["Low"])

    return {
        "place":             place,
        "phase1_risk_used":  round(phase1_used, 4),
        "gnn_refined_label": gnn_label_int,
        "risk_level":        LABEL_MAP[gnn_label_int],
        "gnn_probabilities": {
            "Low":    round(gnn_probs[0], 4),
            "Medium": round(gnn_probs[1], 4),
            "High":   round(gnn_probs[2], 4),
        },
        "note": "GNN spatially refines Phase-1 using label-anchored input score",
    }

# ── POST /predict-full/ ───────────────────────────────────────────
@app.post("/predict-full/")
def predict_full_pipeline(request: FullPredictRequest):
    p1 = predict_phase1(PredictRequest(place=request.place, rainfall_mm=request.rainfall_mm))
    p2 = predict_phase2(GNNRequest(place=request.place))
    return {
        "place":       request.place,
        "rainfall_mm": request.rainfall_mm,
        "phase1": {
            "risk_label":    p1["predicted_risk_label"],
            "risk_score":    p1["phase1_risk_score"],      # now label-anchored score
            "prob_high_raw": p1["prob_high_raw"],          # raw probability for charts
            "probabilities": p1["probabilities"],
        },
        "phase2_gnn": {
            "risk_label":        p2["risk_level"],
            "risk_level_int":    p2["gnn_refined_label"],
            "gnn_probabilities": p2["gnn_probabilities"],
        },
        "final_risk": p2["risk_level"],
    }
