# 🌧️ Thiruvananthapuram Flood Risk Prediction API

This project provides a trained **LightGBM model** and a **FastAPI backend** to predict flood risk levels for different places in Thiruvananthapuram based on rainfall data.

---

## 📂 Contents

| File | Description |
|------|--------------|
| `train_rain_model.py` | Script used to train the LightGBM model on rainfall and risk data. It generates the two `.pkl` model files. |
| `rain_risk_model.pkl` | Trained LightGBM classification model that predicts `Low`, `Medium`, or `High` flood risk. |
| `place_mapping.pkl` | Dictionary mapping each place to its numeric code used in training. |
| `app.py` | FastAPI backend that exposes a `/predict` endpoint for live flood risk predictions. |
| `requirements.txt` | Dependencies required to run the model and API. |

---

## ⚙️ Installation

1. **Create a new environment (recommended)**  
   ```bash
   python -m venv venv
   source venv/bin/activate      # On Windows: venv\Scripts\activate
