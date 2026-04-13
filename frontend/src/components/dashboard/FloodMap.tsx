import { useEffect, useRef } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { FullPipelineResult, AREA_COORDINATES, riskColor } from "@/lib/api";
import { useState } from "react";

delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl:       "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl:     "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

interface Props {
  rainfall: number | null;
  predictions: FullPipelineResult[] | null;
}

export default function FloodMap({ rainfall, predictions }: Props) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef          = useRef<L.Map | null>(null);
  const markersRef      = useRef<L.CircleMarker[]>([]);
  const [useGNN, setUseGNN] = useState(true);

  // Init map once
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;
    mapRef.current = L.map(mapContainerRef.current).setView([8.5100, 76.9366], 12);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
    }).addTo(mapRef.current);

    const karamana: [number, number][] = [
      [8.5569, 76.88], [8.54, 76.9], [8.52, 76.92], [8.50, 76.94],
    ];
    L.polyline(karamana, { color: "#0ea5e9", weight: 4, opacity: 0.7 })
      .addTo(mapRef.current).bindPopup("<strong>Karamana River</strong>");

    const canal: [number, number][] = [
      [8.51, 76.93], [8.50, 76.945], [8.49, 76.955],
    ];
    L.polyline(canal, { color: "#06b6d4", weight: 3, opacity: 0.6 })
      .addTo(mapRef.current).bindPopup("<strong>Parvathy Puthanar Canal</strong>");

    return () => { mapRef.current?.remove(); mapRef.current = null; };
  }, []);

  // Update markers when predictions or toggle changes
  useEffect(() => {
    if (!mapRef.current || !predictions || predictions.length === 0) return;

    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    predictions.forEach((r) => {
      const coords = AREA_COORDINATES[r.place];
      if (!coords) return;

      const label = useGNN ? r.phase2_gnn.risk_label : r.phase1.risk_label;
      const color = riskColor(label);
      const p1    = r.phase1.probabilities;

      const marker = L.circleMarker([coords.lat, coords.lng], {
        radius: 15,
        fillColor: color,
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.75,
      }).addTo(mapRef.current!);

      marker.bindPopup(`
        <div style="font-family: Inter, sans-serif; min-width: 180px;">
          <strong style="font-size:14px;">${r.place}</strong><br/>
          <hr style="margin:4px 0;"/>
          <span style="font-size:11px;color:#888;">Rainfall: ${r.rainfall_mm.toFixed(2)} mm</span><br/>
          <span style="font-size:12px;color:#666;">Phase 1 (LightGBM)</span><br/>
          <span style="color:${riskColor(r.phase1.risk_label)};font-weight:600;">${r.phase1.risk_label}</span>
          &nbsp;<span style="font-size:11px;color:#888;">(High: ${(p1.High * 100).toFixed(1)}%)</span><br/>
          <span style="font-size:12px;color:#666;">Phase 2 (GNN Refined)</span><br/>
          <span style="color:${riskColor(r.phase2_gnn.risk_label)};font-weight:600;">${r.phase2_gnn.risk_label}</span>
        </div>
      `);

      markersRef.current.push(marker);
    });
  }, [predictions, useGNN]);

  return (
    <Card className="card-shadow">
      <CardHeader className="flex flex-row items-center justify-between">
        <div>
          <CardTitle className="text-lg font-semibold">Trivandrum Flood Map — Live Status</CardTitle>
          <p className="text-sm text-muted-foreground">
            Click a marker for Phase 1 vs Phase 2 details
            {rainfall !== null && (
              <span className="ml-2 font-medium text-primary">· Rainfall: {rainfall.toFixed(2)} mm</span>
            )}
          </p>
        </div>
        <div className="flex items-center gap-2 text-sm">
          <span className={!useGNN ? "font-semibold text-primary" : "text-muted-foreground"}>Phase 1</span>
          <button
            onClick={() => setUseGNN((v) => !v)}
            className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none ${
              useGNN ? "bg-primary" : "bg-muted"
            }`}
          >
            <span
              className={`inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform ${
                useGNN ? "translate-x-6" : "translate-x-1"
              }`}
            />
          </button>
          <span className={useGNN ? "font-semibold text-primary" : "text-muted-foreground"}>Phase 2 (GNN)</span>
        </div>
      </CardHeader>
      <CardContent className="p-0 relative">
        {!predictions && (
          <div className="absolute inset-0 z-10 flex items-center justify-center bg-background/60 rounded-b-lg">
            <span className="text-sm text-muted-foreground animate-pulse">Loading predictions…</span>
          </div>
        )}
        <div ref={mapContainerRef} className="h-[430px] w-full rounded-b-lg" />
        <div className="absolute bottom-4 right-4 z-[1000] flex flex-col gap-1 rounded-lg bg-card/90 px-3 py-2 text-xs shadow">
          {[["High", "#ef4444"], ["Medium", "#eab308"], ["Low", "#22c55e"]].map(([l, c]) => (
            <div key={l} className="flex items-center gap-2">
              <span className="inline-block h-3 w-3 rounded-full" style={{ background: c }} />
              <span>{l} Risk</span>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
