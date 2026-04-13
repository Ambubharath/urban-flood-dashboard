import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Separator } from "@/components/ui/separator";
import { Settings2 } from "lucide-react";

export default function Settings() {
  return (
    <div className="space-y-6 animate-fade-in max-w-2xl">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Settings</h1>
        <p className="text-muted-foreground mt-1">Configure API endpoints and display preferences</p>
      </div>

      <Card className="card-shadow">
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings2 className="h-5 w-5 text-primary" />
            API Configuration
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="backend-url">Backend Base URL</Label>
            <Input id="backend-url" defaultValue="http://localhost:8000" />
            <p className="text-xs text-muted-foreground">
              FastAPI server running Phase 1 + Phase 2 endpoints
            </p>
          </div>
          <Separator />
          <div className="space-y-2">
            <Label htmlFor="owm-key">OpenWeatherMap API Key</Label>
            <Input id="owm-key" type="password" defaultValue="0234070d39f15419dcfe80aeeafaee06" />
          </div>
          <Button className="bg-primary hover:bg-primary/90">Save Changes</Button>
        </CardContent>
      </Card>

      <Card className="card-shadow">
        <CardHeader>
          <CardTitle>About This Project</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <p><span className="font-semibold text-foreground">Phase 1:</span> LightGBM model trained on historical rainfall and risk-score data for 14 areas of Thiruvananthapuram. Live rainfall is fetched from OpenWeatherMap and fed into the model to produce a risk label (Low / Medium / High) and a continuous probability score.</p>
          <p><span className="font-semibold text-foreground">Phase 2:</span> Graph Neural Network (GCN) that takes the Phase-1 risk scores as node features and refines them using a spatial adjacency graph of the 14 areas. Neighbouring areas influence each other's final risk score, modelling real-world flood propagation along rivers and canals.</p>
        </CardContent>
      </Card>
    </div>
  );
}
