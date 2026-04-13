import { useMemo } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, Legend,
} from "recharts";
import { FullPipelineResult } from "@/lib/api";

interface Props {
  predictions: FullPipelineResult[] | null;
}

export default function FloodIntensityChart({ predictions }: Props) {
  const data = useMemo(() => {
    if (!predictions) return [];
    return predictions.map((r) => ({
      area:   r.place.length > 9 ? r.place.slice(0, 9) + "…" : r.place,
      phase1: r.phase1.prob_high_raw,
      gnn:    r.phase2_gnn.gnn_probabilities.High,
    }));
  }, [predictions]);

  return (
    <Card className="card-shadow">
      <CardHeader>
        <CardTitle className="text-lg font-semibold">Flood Intensity by Area</CardTitle>
        <p className="text-xs text-muted-foreground">
          Phase 1: High-risk probability · Phase 2: GNN score (0–1)
        </p>
      </CardHeader>
      <CardContent>
        {!predictions ? (
          <div className="flex h-[300px] items-center justify-center text-sm text-muted-foreground animate-pulse">
            Loading predictions…
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={data} margin={{ top: 4, right: 8, left: 0, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
              <XAxis
                dataKey="area"
                stroke="hsl(var(--muted-foreground))"
                style={{ fontSize: "11px" }}
                interval={0}
                angle={-30}
                textAnchor="end"
                height={50}
              />
              <YAxis domain={[0, 1]} stroke="hsl(var(--muted-foreground))" style={{ fontSize: "12px" }} />
              <Tooltip
                contentStyle={{
                  backgroundColor: "hsl(var(--popover))",
                  border: "1px solid hsl(var(--border))",
                  borderRadius: 8,
                }}
                formatter={(value: number, name: string) => [
                  value.toFixed(3),
                  name === "phase1" ? "Phase 1 High-prob" : "Phase 2 GNN High-prob",
                ]}
              />
              <Legend formatter={(v) => v === "phase1" ? "Phase 1 (LightGBM)" : "Phase 2 (GNN)"} />
              <Bar dataKey="phase1" fill="hsl(var(--primary))"   radius={[4, 4, 0, 0]} />
              <Bar dataKey="gnn"    fill="hsl(var(--secondary))" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        )}
      </CardContent>
    </Card>
  );
}
