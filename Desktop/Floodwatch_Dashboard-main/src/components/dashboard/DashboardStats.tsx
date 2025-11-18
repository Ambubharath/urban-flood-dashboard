import { useEffect, useState } from "react";
import StatCard from "@/components/dashboard/StatCard";
import { AlertCircle } from "lucide-react";

// Add the rainfall prop type
interface DashboardStatsProps {
  rainfall: number | null;
}

const areaNames = [
  "Kazhakkoottam", "Manacaud", "Vellayambalam", "Nalanchira", "Pattom",
  "East Fort", "Petta", "Ulloor", "Vanchiyoor", "Thycaud",
  "Vattiyurkkavu", "Chackai", "Sreekaryam", "Peroorkkada"
];

export default function DashboardStats({ rainfall }: DashboardStatsProps) {
  const [data, setData] = useState<any[]>([]);

  useEffect(() => {
    // Only call the API if rainfall is defined (not null)
    if (rainfall === null) return;

    Promise.all(
      areaNames.map(area =>
        fetch("http://localhost:8000/predict", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            place: area,
            rainfall_mm: rainfall  // Use the live rainfall value from prop
          })
        }).then(res => res.json()))
    ).then(setData);
  }, [rainfall]); // Rerun whenever rainfall prop changes

  const highRisk = data.filter(d => d.predicted_risk_label === "High").length;
  const mediumRisk = data.filter(d => d.predicted_risk_label === "Medium").length;
  const lowRisk = data.filter(d => d.predicted_risk_label === "Low").length;

  return (
    <div className="grid grid-cols-3 gap-4">
      <StatCard title="High Risk Zones" value={highRisk.toString()} icon={AlertCircle} />
      <StatCard title="Medium Risk Zones" value={mediumRisk.toString()} icon={AlertCircle} />
      <StatCard title="Low Risk Zones" value={lowRisk.toString()} icon={AlertCircle} />
    </div>
  );
}
