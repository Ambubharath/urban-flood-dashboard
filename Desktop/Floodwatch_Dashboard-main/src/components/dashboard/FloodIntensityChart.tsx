import React, { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from "recharts";

interface FloodIntensityChartProps {
  rainfall: number | null;
}

const areaNames = [
  "Kazhakkoottam", "Manacaud", "Vellayambalam", "Nalanchira", "Pattom",
  "East Fort", "Petta", "Ulloor", "Vanchiyoor", "Thycaud",
  "Vattiyurkkavu", "Chackai", "Sreekaryam", "Peroorkkada"
];

export default function FloodIntensityChart({ rainfall }: FloodIntensityChartProps) {
  const [data, setData] = useState<any[]>([]);

  useEffect(() => {
    if (rainfall === null) return;

    Promise.all(
      areaNames.map(area =>
        fetch("http://localhost:8000/predict/", {  // Trailing slash matches backend
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            place: area,
            rainfall_mm: rainfall,
          }),
        })
          .then(res => res.json())
          .then(pred =>
            (pred && pred.probabilities && typeof pred.probabilities.High === "number")
              ? { area, intensity: pred.probabilities.High }
              : { area, intensity: 0 }
          )
          .catch(() => ({ area, intensity: 0 }))
      )
    ).then(results => {
      setData(results);
    });
  }, [rainfall]);

  return (
    <Card className="card-shadow">
      <CardHeader>
        <CardTitle className="text-lg font-semibold">Flood Intensity by Area</CardTitle>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="area" stroke="hsl(var(--muted-foreground))" style={{ fontSize: "12px" }} />
            <YAxis
              stroke="hsl(var(--muted-foreground))"
              style={{ fontSize: "12px" }}
              label={{ value: "High risk probability", angle: -90, position: "insideLeft" }}
            />
            <Tooltip contentStyle={{ backgroundColor: "hsl(var(--popover))", border: "1px solid hsl(var(--border))", borderRadius: 8 }} />
            <Bar dataKey="intensity" fill="hsl(var(--secondary))" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
