import { useEffect, useState } from "react";
import DashboardStats from "@/components/dashboard/DashboardStats";
import RainfallChart from "@/components/dashboard/RainfallChart";
import FloodIntensityChart from "@/components/dashboard/FloodIntensityChart";
import FloodMap from "@/components/dashboard/FloodMap";

export default function Dashboard() {
  const [rainfall, setRainfall] = useState<number | null>(null);

  useEffect(() => {
    async function fetchRainfall() {
      try {
        const response = await fetch(
          "https://api.openweathermap.org/data/3.0/onecall?lat=8.5241&lon=76.9366&exclude=current,minutely,hourly,alerts&units=metric&appid=0234070d39f15419dcfe80aeeafaee06"
        );
        const data = await response.json();
        // Today's rainfall or 0 if missing
        const todayRain = data?.daily?.[0]?.rain ?? 0;
        setRainfall(todayRain);
      } catch (error) {
        console.error("Failed to fetch rainfall:", error);
        setRainfall(0);
      }
    }
    fetchRainfall();
  }, []);

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Dashboard Overview</h1>
        <p className="text-muted-foreground mt-1">
          Monitor real-time flood conditions and system metrics
        </p>
      </div>

      {/* Pass live rainfall to these components */}
      <DashboardStats rainfall={rainfall} />
      <div className="grid gap-6 lg:grid-cols-2">
        <RainfallChart />
        <FloodIntensityChart rainfall={rainfall} />
      </div>
      <FloodMap rainfall={rainfall} />
    </div>
  );
}
