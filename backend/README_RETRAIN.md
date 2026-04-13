# Retraining the GNN (Phase 2)

## Why you need to retrain
The `gnn_model.pth` included in this repo was trained with the OLD architecture
(3-feature input, no class weights). It collapses all predictions to "Low" when
phase1_risk values are similar.

The new architecture uses **5 features** per node and **weighted loss**. You must
retrain to get correct Medium/High outputs from the GNN.

## Steps

```bash
cd flood_project/backend

# 1. Create and activate virtualenv
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Retrain the GNN (takes ~5 minutes on CPU)
python train_gnn.py
```

## What train_gnn.py produces
- `gnn_model.pth`          — updated model weights (5-feature, 3-class)
- `gnn_node_features.json` — static per-place features for inference

## Then start the API
```bash
uvicorn main:app --reload --port 8000
```

## How to verify GNN is working
1. Open http://localhost:8000/docs
2. Call `/predict/` for Petta with rainfall_mm=35.0
   → should return "Medium" or "High" for Phase1
3. Call `/predict-full/` for same
   → `phase2_gnn.risk_label` should NOT always be "Low"
4. Open http://localhost:8000/debug/areas/
   → confirm phase1_risk values are non-zero after running /predict/

## Root cause of "all Low from GNN"
The old model was trained on discrete risk_score values (0.2/0.5/0.8 only).
When all 14 nodes get the same score (e.g. all 0.2), the GNN cannot distinguish
between them and predicts the majority class (Low=55%). The new training:
- Uses continuous noisy scores (0.0–1.0 range)
- Adds flood_freq and high_freq as stable spatial discriminators
- Uses inverse-frequency class weights to balance Low/Medium/High
