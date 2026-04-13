# Trivandrum Flood Prediction — Backend

## Setup

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

API docs available at: http://localhost:8000/docs

---

## Endpoints

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/` | Health check |
| GET | `/places/` | List all known area names |
| POST | `/predict/` | Phase 1: LightGBM risk prediction |
| POST | `/predict-gnn/` | Phase 2: GNN spatial refinement |
| POST | `/predict-full/` | Full pipeline (Phase 1 + Phase 2) |

### POST `/predict/`
```json
{ "place": "Pattom", "rainfall_mm": 45.0 }
```
Returns risk label (Low/Medium/High), probabilities, and phase1_risk score.
Also updates `areas.csv` with the latest phase1_risk for GNN use.

### POST `/predict-gnn/`
```json
{ "place": "Pattom" }
```
Runs GNN using the latest `phase1_risk` in `areas.csv`.

### POST `/predict-full/`
```json
{ "place": "Pattom", "rainfall_mm": 45.0 }
```
Runs both phases and returns combined results.

---

## Retraining

### Phase 1 (LightGBM)
```bash
python train_rain_model.py
```

### Phase 2 (GNN)
First populate `areas.csv` with Phase-1 scores by calling `/predict/` for each area,
then:
```bash
python train_gnn.py
```

### Regenerate edges
```bash
python create_edges.py
```
