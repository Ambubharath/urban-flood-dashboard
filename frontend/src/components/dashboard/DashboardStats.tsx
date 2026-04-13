import StatCard from "@/components/dashboard/StatCard";
import { AlertCircle, ShieldAlert, CheckCircle2, Cpu, Loader2 } from "lucide-react";
import { FullPipelineResult } from "@/lib/api";

interface Props {
  predictions: FullPipelineResult[] | null;
  loadingPredictions: boolean;
}

export default function DashboardStats({ predictions, loadingPredictions }: Props) {
  const results = predictions ?? [];

  const p1High   = results.filter((r) => r.phase1.risk_label === "High").length;
  const p1Medium = results.filter((r) => r.phase1.risk_label === "Medium").length;
  const p1Low    = results.filter((r) => r.phase1.risk_label === "Low").length;

  const p2High   = results.filter((r) => r.phase2_gnn.risk_label === "High").length;
  const p2Medium = results.filter((r) => r.phase2_gnn.risk_label === "Medium").length;
  const p2Low    = results.filter((r) => r.phase2_gnn.risk_label === "Low").length;

  const val = (n: number) =>
    loadingPredictions ? <Loader2 className="h-5 w-5 animate-spin text-muted-foreground" /> : n.toString();

  return (
    <div className="space-y-3">
      <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">
        Phase 1 — LightGBM Prediction
      </p>
      <div className="grid grid-cols-3 gap-4">
        <StatCard title="High Risk Zones"   value={val(p1High)}   icon={AlertCircle}  color="text-red-500" />
        <StatCard title="Medium Risk Zones" value={val(p1Medium)} icon={ShieldAlert}  color="text-yellow-500" />
        <StatCard title="Low Risk Zones"    value={val(p1Low)}    icon={CheckCircle2} color="text-green-500" />
      </div>

      <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground mt-2">
        Phase 2 — GNN Refined Prediction
      </p>
      <div className="grid grid-cols-3 gap-4">
        <StatCard title="High Risk (GNN)"   value={val(p2High)}   icon={Cpu} color="text-red-500" />
        <StatCard title="Medium Risk (GNN)" value={val(p2Medium)} icon={Cpu} color="text-yellow-500" />
        <StatCard title="Low Risk (GNN)"    value={val(p2Low)}    icon={Cpu} color="text-green-500" />
      </div>
    </div>
  );
}
