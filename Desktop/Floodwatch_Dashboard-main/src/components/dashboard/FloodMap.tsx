import { useEffect, useRef, useState } from "react";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

// Fix for default marker icons in Leaflet
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
});

const areaCoordinates: Record<string, { lat: number; lng: number }> = {
  Kazhakkoottam: { lat: 8.430, lng: 76.990 },
  Manacaud: { lat: 8.488, lng: 76.972 },
  Vellayambalam: { lat: 8.5213, lng: 76.9712 },
  Nalanchira: { lat: 8.5418, lng: 76.9658 },
  Pattom: { lat: 8.5158, lng: 76.9558 },
  "East Fort": { lat: 8.4862, lng: 76.947 },
  Petta: { lat: 8.4855, lng: 76.9492 },
  Ulloor: { lat: 8.5034, lng: 76.9604 },
  Vanchiyoor: { lat: 8.4981, lng: 76.943 },
  Thycaud: { lat: 8.4891, lng: 76.9525 },
  Vattiyurkkavu: { lat: 8.538, lng: 76.9125 },
  Chackai: { lat: 8.4992, lng: 76.9458 },
  Sreekaryam: { lat: 8.544, lng: 76.9876 },
  Peroorkkada: { lat: 8.5429, lng: 76.9475 },
};

const areaNames = Object.keys(areaCoordinates);

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case "High": return "#ef4444";
    case "Medium": return "#eab308";
    case "Low": default: return "#22c55e";
  }
};

interface FloodMapProps {
  rainfall: number | null;
}

export default function FloodMap({ rainfall }: FloodMapProps) {
  const mapRef = useRef<L.Map | null>(null);
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const [predictions, setPredictions] = useState<any[]>([]);

  useEffect(() => {
    if (rainfall === null) return;
    Promise.all(
      areaNames.map((area) =>
        fetch("http://localhost:8000/predict/", {  // Trailing slash matches backend!
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ place: area, rainfall_mm: rainfall ?? 0 }),
        })
          .then((res) => res.json())
          .then((pred) =>
            pred && typeof pred.predicted_risk_label === "string" && pred.probabilities
              ? {
                  ...areaCoordinates[area],
                  name: area,
                  severity: pred.predicted_risk_label,
                  probabilities: pred.probabilities,
                }
              : {
                  ...areaCoordinates[area],
                  name: area,
                  severity: "Low",
                  probabilities: { Low: 1, Medium: 0, High: 0 },
                }
          )
          .catch(() => ({
            ...areaCoordinates[area],
            name: area,
            severity: "Low",
            probabilities: { Low: 1, Medium: 0, High: 0 },
          }))
      )
    ).then(setPredictions);
  }, [rainfall]);

  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current || predictions.length === 0)
      return;

    mapRef.current = L.map(mapContainerRef.current).setView([8.5241, 76.9366], 12);

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors",
    }).addTo(mapRef.current);

    // Add waterbody polylines
    const karamanaRiver: [number, number][] = [
      [8.5569, 76.88], [8.54, 76.9], [8.52, 76.92], [8.5, 76.94],
    ];
    L.polyline(karamanaRiver, { color: "#0ea5e9", weight: 4, opacity: 0.7 })
      .addTo(mapRef.current)
      .bindPopup("<strong>Karamana River</strong>");

    const parvathyCanal: [number, number][] = [
      [8.51, 76.93], [8.5, 76.945], [8.49, 76.955],
    ];
    L.polyline(parvathyCanal, { color: "#06b6d4", weight: 3, opacity: 0.6 })
      .addTo(mapRef.current)
      .bindPopup("<strong>Parvathy Puthanar Canal</strong>");

    // Safe rendering: fallback for undefined .probabilities
    predictions.forEach((zone) => {
      const probs = zone.probabilities || { Low: "-", Medium: "-", High: "-" };
      const marker = L.circleMarker([zone.lat, zone.lng], {
        radius: 15,
        fillColor: getSeverityColor(zone.severity),
        color: "#fff",
        weight: 2,
        opacity: 1,
        fillOpacity: 0.7,
      }).addTo(mapRef.current!);

      marker.bindPopup(`
        <div style="font-family: 'Poppins', sans-serif;">
          <strong style="font-size: 14px;">${zone.name}</strong><br/>
          <span style="color: ${getSeverityColor(zone.severity)}; text-transform: capitalize; font-weight: 600;">
            ${zone.severity}
          </span> severity<br/>
          <span style="font-size: 12px; color: #666;">
            L: ${typeof probs.Low == "number" ? probs.Low : "-"}, 
            M: ${typeof probs.Medium == "number" ? probs.Medium : "-"},
            H: ${typeof probs.High == "number" ? probs.High : "-"}
          </span>
        </div>
      `);
    });

    return () => {
      if (mapRef.current) {
        mapRef.current.remove();
        mapRef.current = null;
      }
    };
  }, [predictions]);

  return (
    <Card className="card-shadow">
      <CardHeader>
        <CardTitle className="text-lg font-semibold">Trivandrum Flood Map - Live Status</CardTitle>
        <p className="text-sm text-muted-foreground">Real-time monitoring of flood zones and waterways</p>
      </CardHeader>
      <CardContent className="p-0">
        <div ref={mapContainerRef} className="h-[400px] w-full rounded-b-lg" />
      </CardContent>
    </Card>
  );
}
