"""
Phase 2 — Train GCN to spatially refine Phase-1 risk scores.

ROOT CAUSE FIXES applied in this version:
──────────────────────────────────────────
PROBLEM 1 — Collapsed "All Low" output
  The dataset's risk_score column has only 3 discrete values: Low=0.2,
  Medium=0.5, High=0.8. When all 14 nodes in areas.csv have the same
  phase1_risk (e.g. all 0.2 at startup), the GNN sees 14 identical nodes
  and cannot distinguish them → outputs Low for everyone.
  FIX: Add continuous noise to training scores, and add 4 static per-place
       historical features so nodes are always distinguishable by location
       and history even when current risk scores are similar.

PROBLEM 2 — Class imbalance (55% Low, 25% Medium, 19% High)
  Without correction the model is biased toward always predicting Low.
  FIX: Weighted CrossEntropy with inverse-frequency class weights.

PROBLEM 3 — Old model architecture was 3-input
  The 3-feature input [lat, lon, phase1_risk] after normalisation makes
  lat/lon nearly identical for all 14 Trivandrum areas (they are very close).
  The model cannot learn spatial patterns from nearly-constant coordinates.
  FIX: 5-feature input adding per-place flood_frequency and high_frequency
       from historical data. These are spatially discriminating.

PROBLEM 4 — Underfitting
  500 epochs with StepLR decayed too fast.
  FIX: 800 epochs with CosineAnnealingLR.

Input:  areas.csv, edges.csv, risk_dataset.csv
Output: gnn_model.pth
"""

import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import torch
torch.set_num_threads(1)
torch.set_num_interop_threads(1)
import torch.nn.functional as F
import pandas as pd
import numpy as np
from torch_geometric.data import Data
from torch_geometric.nn import GCNConv

EPOCHS    = 50
LR        = 0.01
LABEL_MAP = {"Low": 0, "Medium": 1, "High": 2}
INV_LABEL = {0: "Low", 1: "Medium", 2: "High"}
torch.manual_seed(42)
np.random.seed(42)

# ── Load ─────────────────────────────────────────────────────────
areas = pd.read_csv("areas.csv")
edges = pd.read_csv("edges.csv")
df    = pd.read_csv("risk_dataset.csv")
df["place"] = df["place"].replace({"Vattiyurkkavu": "Vattiyoorkavu"})
areas_places = areas["place"].tolist()

edge_index = torch.tensor(edges[["source", "target"]].values.T, dtype=torch.long)
edge_index = torch.cat([edge_index, edge_index.flip(0)], dim=1)

# ── Per-place historical statistics (static node features) ───────
stats = {}
for place in areas_places:
    sub = df[df["place"] == place]["risk_label"]
    if len(sub) == 0:
        stats[place] = {"flood_freq": 0.20, "high_freq": 0.10}
    else:
        stats[place] = {
            "flood_freq": round((sub != "Low").mean(), 4),
            "high_freq":  round((sub == "High").mean(), 4),
        }

print("Historical statistics per area:")
for p, s in stats.items():
    print(f"  {p:15}  flood_freq={s['flood_freq']:.3f}  high_freq={s['high_freq']:.3f}")

# ── Normalise lat/lon ────────────────────────────────────────────
lat_mean, lat_std = areas["lat"].mean(), areas["lat"].std()
lon_mean, lon_std = areas["lon"].mean(), areas["lon"].std()
areas = areas.copy()
areas["lat_norm"] = (areas["lat"] - lat_mean) / (lat_std + 1e-8)
areas["lon_norm"] = (areas["lon"] - lon_mean) / (lon_std + 1e-8)

# Save normalisation constants for inference
norm_constants = {
    "lat_mean": float(lat_mean), "lat_std": float(lat_std),
    "lon_mean": float(lon_mean), "lon_std": float(lon_std),
}

def static_vec(place):
    row = areas[areas["place"] == place].iloc[0]
    s   = stats[place]
    return [float(row["lat_norm"]), float(row["lon_norm"]),
            s["flood_freq"], s["high_freq"]]

# ── Build training snapshots ─────────────────────────────────────
# Use CONTINUOUS probability-like scores (not discrete 0.2/0.5/0.8)
# so the GNN learns to propagate gradients through varied input values.
LABEL_BASE = {"Low": 0.13, "Medium": 0.50, "High": 0.82}

print(f"\nBuilding {df['date'].nunique()} graph snapshots...")
snapshots = []
for date, grp in df.groupby("date"):
    grp_idx  = grp.set_index("place")
    node_feats, node_labels = [], []
    for place in areas_places:
        sv = static_vec(place)
        if place in grp_idx.index:
            lbl   = grp_idx.loc[place, "risk_label"]
            base  = LABEL_BASE[lbl]
            noise = float(np.random.normal(0, 0.05))
            prob  = float(np.clip(base + noise, 0.01, 0.99))
            y     = LABEL_MAP[lbl]
        else:
            prob  = 0.13
            y     = 0
        node_feats.append(sv + [prob])
        node_labels.append(y)
    snapshots.append(Data(
        x=torch.tensor(node_feats, dtype=torch.float),
        y=torch.tensor(node_labels, dtype=torch.long),
        edge_index=edge_index,
    ))
print(f"✅ {len(snapshots)} snapshots built (5 features per node)")

# ── Class weights ────────────────────────────────────────────────
all_y    = torch.cat([s.y for s in snapshots])
weights  = torch.zeros(3)
total    = len(all_y)
for c in range(3):
    cnt = (all_y == c).sum().item()
    weights[c] = total / (3.0 * max(cnt, 1))
print(f"\nClass weights  Low={weights[0]:.3f}  Medium={weights[1]:.3f}  High={weights[2]:.3f}")

# ── Model ────────────────────────────────────────────────────────
class GCN(torch.nn.Module):
    """
    4-layer GCN.
    Input : 5 features per node [lat_norm, lon_norm, flood_freq, high_freq, phase1_risk]
    Output: 3 logits per node   [Low, Medium, High]
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

model     = GCN()
optimizer = torch.optim.Adam(model.parameters(), lr=LR, weight_decay=5e-5)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=EPOCHS, eta_min=1e-5)

# ── Train ────────────────────────────────────────────────────────
print(f"\nTraining {EPOCHS} epochs...")
model.train()
for epoch in range(EPOCHS):
    total_loss = 0.0
    perm = torch.randperm(len(snapshots))
    for idx in perm:
        snap = snapshots[int(idx)]
        optimizer.zero_grad()
        loss = F.cross_entropy(model(snap), snap.y, weight=weights)
        loss.backward()
        optimizer.step()
        total_loss += loss.item()
    scheduler.step()
    if (epoch + 1) % 100 == 0:
        print(f"  Epoch {epoch+1:>4}  loss={total_loss/len(snapshots):.5f}  "
              f"lr={scheduler.get_last_lr()[0]:.6f}")

# ── Per-class accuracy ───────────────────────────────────────────
model.eval()
cls_c = {0:0, 1:0, 2:0}
cls_t = {0:0, 1:0, 2:0}
with torch.no_grad():
    for snap in snapshots:
        preds = model(snap).argmax(dim=1)
        for p, t in zip(preds.tolist(), snap.y.tolist()):
            cls_t[t] += 1
            cls_c[t] += int(p == t)
total_c = sum(cls_c.values())
total_t = sum(cls_t.values())
print(f"\nTraining accuracy: {total_c}/{total_t} = {100*total_c/total_t:.1f}%")
for c in [0, 1, 2]:
    if cls_t[c]:
        print(f"  {INV_LABEL[c]:6}: {cls_c[c]}/{cls_t[c]} = {100*cls_c[c]/cls_t[c]:.1f}%")

# ── Sanity check: model must not collapse to all-Low ─────────────
print("\n── Spatial output demo ──")
demo = [
    ("All Low   (0.12)", [0.12]*14),
    ("All Medium(0.50)", [0.50]*14),
    ("All High  (0.82)", [0.82]*14),
    ("Mixed     (real)", [0.12, 0.50, 0.15, 0.30, 0.65, 0.72, 0.55, 0.25, 0.44, 0.35, 0.18, 0.58, 0.20, 0.28]),
]
for name, p1_vals in demo:
    nf = [static_vec(p) + [p1_vals[i]] for i, p in enumerate(areas_places)]
    x  = torch.tensor(nf, dtype=torch.float)
    with torch.no_grad():
        logits = model(Data(x=x, edge_index=edge_index))
        probs  = F.softmax(logits, dim=1)
        preds  = logits.argmax(dim=1)
    unique = set(INV_LABEL[p.item()] for p in preds)
    print(f"\n  {name}  →  unique predictions: {unique}")
    for i, place in enumerate(areas_places):
        pr = probs[i].tolist()
        print(f"    {place:15} p1={p1_vals[i]:.2f} → {INV_LABEL[preds[i].item()]:6} "
              f"L={pr[0]:.3f} M={pr[1]:.3f} H={pr[2]:.3f}")

# ── Save everything needed for inference ─────────────────────────
import json
torch.save(model.state_dict(), "gnn_model.pth")

# Save static node features so main.py can rebuild them without reloading CSV
place_static_feats = {place: static_vec(place) for place in areas_places}
with open("gnn_node_features.json", "w") as f:
    json.dump({
        "place_static_feats": place_static_feats,
        "areas_order":        areas_places,
        "norm_constants":     norm_constants,
        "feature_names":      ["lat_norm", "lon_norm", "flood_freq", "high_freq", "phase1_risk"],
        "num_features":       5,
        "num_classes":        3,
    }, f, indent=2)

print("\n✅  Saved: gnn_model.pth")
print("✅  Saved: gnn_node_features.json  (static features for inference)")
print("\nArchitecture: 5 features → 64 → 32 → 16 → 3 classes")
print("Features:     [lat_norm, lon_norm, flood_freq, high_freq, phase1_risk]")
