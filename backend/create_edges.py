"""
Utility — generate edges.csv from areas.csv based on geographic proximity.
Two areas are connected if they are within `threshold_km` of each other.

Usage:
    python create_edges.py
"""

import pandas as pd
import math

THRESHOLD_KM = 3.0   # connect areas within 3 km

def haversine(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2))
         * math.sin(dlon / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))

areas = pd.read_csv("areas.csv")
edges = []

for i, row_i in areas.iterrows():
    for j, row_j in areas.iterrows():
        if i >= j:
            continue
        dist = haversine(row_i["lat"], row_i["lon"], row_j["lat"], row_j["lon"])
        if dist <= THRESHOLD_KM:
            edges.append({"source": int(row_i["area_id"]), "target": int(row_j["area_id"])})

df_edges = pd.DataFrame(edges)
df_edges.to_csv("edges.csv", index=False)
print(f"✅ Created edges.csv with {len(df_edges)} edges (threshold={THRESHOLD_KM} km)")
