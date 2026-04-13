import pandas as pd
import lightgbm as lgb
import joblib

# Load and clean
data = pd.read_csv("risk_dataset.csv")
data.columns = data.columns.str.strip().str.lower()  # Remove spaces and lowercase

# Encode place safely
if 'place' not in data.columns:
    raise ValueError(f"'place' column not found! Columns available: {data.columns.tolist()}")

data['place'] = data['place'].astype('category')
data['place_code'] = data['place'].cat.codes

# Features & target
X = data[['rainfall_mm', 'place_code']]
y = data['risk_label']

# Train model
model = lgb.LGBMClassifier()
model.fit(X, y)

# Save model and mapping
joblib.dump(model, 'rain_risk_model.pkl')
joblib.dump(dict(enumerate(data['place'].cat.categories)), 'place_mapping.pkl')

print("✅ Model trained successfully and saved as 'rain_risk_model.pkl'")
