import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer,
} from "recharts";

const OWM_KEY = "0234070d39f15419dcfe80aeeafaee06";
const DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default function RainfallChart() {
  const [data, setData] = useState<{ day: string; rainfall: number }[]>([]);

  useEffect(() => {
    async function fetchForecast() {
      try {
        const res = await fetch(
          `https://api.openweathermap.org/data/3.0/onecall?lat=8.5241&lon=76.9366&exclude=current,minutely,hourly,alerts&units=metric&appid=${OWM_KEY}`
        );
        const json = await res.json();
        const today = new Date().getDay(); // 0=Sun … 6=Sat
        const trend = (json.daily ?? []).slice(0, 7).map((d: any, i: number) => ({
          day: DAYS[(today + i) % 7],
          rainfall: +(d.rain ?? 0).toFixed(2),
        }));
        setData(trend);
      } catch {
        setData(DAYS.map((day) => ({ day, rainfall: 0 })));
      }
    }
    fetchForecast();
  }, []);

  return (
    <Card className="card-shadow">
      <CardHeader>
        <CardTitle className="text-lg font-semibold">Rainfall Forecast (7 Days)</CardTitle>
        <p className="text-xs text-muted-foreground">Trivandrum — OpenWeatherMap</p>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
            <XAxis dataKey="day" stroke="hsl(var(--muted-foreground))" style={{ fontSize: "12px" }} />
            <YAxis
              stroke="hsl(var(--muted-foreground))"
              style={{ fontSize: "12px" }}
              label={{ value: "mm", angle: -90, position: "insideLeft" }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "hsl(var(--popover))",
                border: "1px solid hsl(var(--border))",
                borderRadius: "8px",
              }}
            />
            <Line
              type="monotone"
              dataKey="rainfall"
              stroke="hsl(var(--primary))"
              strokeWidth={3}
              dot={{ fill: "hsl(var(--primary))", r: 4 }}
              activeDot={{ r: 6 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
