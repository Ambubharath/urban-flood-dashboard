"""
Phase 1 — Train LightGBM rainfall-to-risk model.
Input:  risk_dataset.csv  (date, rainfall_mm, place, risk_label, risk_score, ...)
Output: rain_risk_model.pkl, place_mapping.pkl
"""

import pandas as pd
import joblib
from lightgbm import LGBMClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# ── Load data ──────────────────────────────────────────────────
df = pd.read_csv("risk_dataset.csv")

# Drop helper columns that leaked local paths
df = df.drop(columns=["source_file"], errors="ignore")

# Encode place names → integer codes
places = df["place"].unique()
place_mapping = {i: p for i, p in enumerate(sorted(places))}   # code → name
place_to_code = {v: k for k, v in place_mapping.items()}        # name → code
df["place_code"] = df["place"].map(place_to_code)

# Encode risk_label: Low=0, Medium=1, High=2
label_map = {"Low": 0, "Medium": 1, "High": 2}
df["label"] = df["risk_label"].map(label_map)

X = df[["rainfall_mm", "place_code"]]
y = df["label"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# ── Train ───────────────────────────────────────────────────────
model = LGBMClassifier(n_estimators=200, learning_rate=0.05, random_state=42)
model.fit(X_train, y_train)

print("── Classification Report ──")
print(classification_report(y_test, model.predict(X_test),
                             target_names=["Low", "Medium", "High"]))

# ── Save ────────────────────────────────────────────────────────
joblib.dump(model, "rain_risk_model.pkl")
joblib.dump(place_mapping, "place_mapping.pkl")
print("✅ Saved: rain_risk_model.pkl, place_mapping.pkl")
