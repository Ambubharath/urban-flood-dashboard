import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Cpu, Loader2 } from "lucide-react";
import { FullPipelineResult } from "@/lib/api";

interface Props {
  predictions: FullPipelineResult[] | null;
  loadingPredictions: boolean;
}

const RiskBadge = ({ label }: { label: string }) => {
  const color =
    label === "High"   ? "bg-red-100 text-red-700 border-red-200" :
    label === "Medium" ? "bg-yellow-100 text-yellow-700 border-yellow-200" :
                         "bg-green-100 text-green-700 border-green-200";
  return <Badge variant="outline" className={color}>{label}</Badge>;
};

export default function GNNComparisonTable({ predictions, loadingPredictions }: Props) {
  return (
    <Card className="card-shadow">
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-lg font-semibold">
          <Cpu className="h-5 w-5 text-primary" />
          Phase 1 vs Phase 2 (GNN) — All Areas
        </CardTitle>
        <p className="text-xs text-muted-foreground">
          ↑ GNN raised risk · ↓ GNN lowered risk · — no change
        </p>
      </CardHeader>
      <CardContent>
        {loadingPredictions || !predictions ? (
          <div className="flex items-center gap-2 text-sm text-muted-foreground py-6 justify-center">
            <Loader2 className="h-4 w-4 animate-spin" />
            Loading predictions…
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="pb-2 pr-4 font-medium">Area</th>
                  <th className="pb-2 pr-4 font-medium">Rainfall (mm)</th>
                  <th className="pb-2 pr-4 font-medium">P1 High prob</th>
                  <th className="pb-2 pr-4 font-medium">Phase 1</th>
                  <th className="pb-2 pr-4 font-medium">Phase 2 (GNN)</th>
                  <th className="pb-2 font-medium">Change</th>
                </tr>
              </thead>
              <tbody>
                {predictions.map((r) => {
                  const levels: Record<string, number> = { Low: 0, Medium: 1, High: 2 };
                  const diff = levels[r.phase2_gnn.risk_label] - levels[r.phase1.risk_label];
                  const changeIcon = diff > 0 ? "↑" : diff < 0 ? "↓" : "—";
                  const changeColor =
                    diff > 0 ? "text-red-500" :
                    diff < 0 ? "text-green-500" :
                    "text-muted-foreground";
                  return (
                    <tr key={r.place} className="border-b last:border-0 hover:bg-muted/40 transition-colors">
                      <td className="py-2 pr-4 font-medium">{r.place}</td>
                      <td className="py-2 pr-4 text-muted-foreground">{r.rainfall_mm.toFixed(2)}</td>
                      <td className="py-2 pr-4 text-muted-foreground font-mono text-xs">
                        {((r.phase1.prob_high_raw ?? r.phase1.probabilities.High) * 100).toFixed(1)}%
                      </td>
                      <td className="py-2 pr-4"><RiskBadge label={r.phase1.risk_label} /></td>
                      <td className="py-2 pr-4"><RiskBadge label={r.phase2_gnn.risk_label} /></td>
                      <td className={`py-2 font-bold text-lg ${changeColor}`}>{changeIcon}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
