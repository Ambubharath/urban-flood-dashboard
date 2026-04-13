"""
bootstrap_gnn.py — Run this ONCE to create a valid gnn_model.pth
that matches the new 5-feature architecture, before you run train_gnn.py.

This creates a randomly-initialised model (not trained yet).
It ensures the server starts without crashing on shape mismatch.
Then run train_gnn.py to get a properly trained model.

Usage:
    python bootstrap_gnn.py
    uvicorn main:app --reload    # now works
    python train_gnn.py          # trains for real (5-10 min)
    # restart uvicorn             # picks up the trained weights
"""

import torch
import torch.nn.functional as F
from torch_geometric.nn import GCNConv
import os

class GCN(torch.nn.Module):
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
        x = F.relu(self.bn2(self.conv2(x, ei)))
        x = F.relu(self.conv3(x, ei))
        x = self.conv4(x, ei)
        return x

torch.manual_seed(0)
model = GCN()

# Save
torch.save(model.state_dict(), "gnn_model.pth")
print("✅ gnn_model.pth created with 5-feature architecture (random weights)")
print("   Run  python train_gnn.py  to train it properly.")
print("   Then restart uvicorn to load the trained weights.")

# Quick shape check
from torch_geometric.data import Data
dummy_x = torch.randn(14, 5)
dummy_e = torch.tensor([[0,1,2],[1,2,3]], dtype=torch.long)
model.eval()
with torch.no_grad():
    out = model(Data(x=dummy_x, edge_index=dummy_e))
print(f"   Shape check: input [14,5] → output {list(out.shape)}  ✅")
