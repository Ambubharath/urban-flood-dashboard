from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import joblib
import pandas as pd

model = joblib.load("rain_risk_model.pkl")
place_mapping = joblib.load("place_mapping.pkl")
place_to_code = {v: k for k, v in place_mapping.items()}

app = FastAPI(title="Thiruvananthapuram Flood Risk API")

# 🔥 CORS FIX (REQUIRED FOR FLUTTER WEB)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    return {"message": "✅ API running"}

@app.post("/predict/")
def predict_risk(place: str, rainfall_mm: float):
    place_code = place_to_code.get(place)
    if place_code is None:
        return {"error": f"Unknown place '{place}'"}

    X = pd.DataFrame([[rainfall_mm, place_code]],
                     columns=["rainfall_mm", "place_code"])

    pred_label = model.predict(X)[0]
    pred_probs = model.predict_proba(X)[0]

    return {
        "place": place,
        "rainfall_mm": rainfall_mm,
        "predicted_risk_label": pred_label,
        "probabilities": {
            "Low": round(pred_probs[0], 3),
            "Medium": round(pred_probs[1], 3),
            "High": round(pred_probs[2], 3),
        },
    }
