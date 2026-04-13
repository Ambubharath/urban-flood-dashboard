import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Switch } from "@/components/ui/switch";
import { Separator } from "@/components/ui/separator";
import { Settings as SettingsIcon, Users, Database, Zap } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

export default function Settings() {
  const { toast } = useToast();

  const handleSave = () => {
    toast({
      title: "Settings Saved",
      description: "Your changes have been saved successfully",
    });
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Settings</h1>
        <p className="text-muted-foreground mt-1">Manage system configuration and preferences</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* User Management */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Users className="h-5 w-5 text-primary" />
              User Management
            </CardTitle>
            <CardDescription>Add or remove admin users</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="admin-email">Admin Email</Label>
              <Input id="admin-email" type="email" placeholder="admin@smartcity.gov" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="admin-role">Role</Label>
              <Input id="admin-role" placeholder="Administrator" />
            </div>
            <Button className="w-full bg-primary hover:bg-primary/90">
              Add Admin User
            </Button>
          </CardContent>
        </Card>

        {/* Flood Zone Parameters */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Database className="h-5 w-5 text-primary" />
              Flood Zone Parameters
            </CardTitle>
            <CardDescription>Configure thresholds and severity levels</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="critical-threshold">Critical Threshold (mm)</Label>
              <Input id="critical-threshold" type="number" placeholder="100" defaultValue="100" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="high-threshold">High Threshold (mm)</Label>
              <Input id="high-threshold" type="number" placeholder="75" defaultValue="75" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="moderate-threshold">Moderate Threshold (mm)</Label>
              <Input id="moderate-threshold" type="number" placeholder="50" defaultValue="50" />
            </div>
          </CardContent>
        </Card>

        {/* System Configuration */}
        <Card className="card-shadow lg:col-span-2">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Zap className="h-5 w-5 text-primary" />
              System Configuration
            </CardTitle>
            <CardDescription>Advanced system settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label htmlFor="maintenance-mode" className="text-base">Maintenance Mode</Label>
                <p className="text-sm text-muted-foreground">
                  Temporarily disable public access to the system
                </p>
              </div>
              <Switch id="maintenance-mode" />
            </div>

            <Separator />

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label htmlFor="simulation-mode" className="text-base">Simulation Mode</Label>
                <p className="text-sm text-muted-foreground">
                  Use simulated data for testing and training
                </p>
              </div>
              <Switch id="simulation-mode" />
            </div>

            <Separator />

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label htmlFor="auto-alerts" className="text-base">Automatic Alerts</Label>
                <p className="text-sm text-muted-foreground">
                  Send alerts automatically when thresholds are exceeded
                </p>
              </div>
              <Switch id="auto-alerts" defaultChecked />
            </div>

            <Separator />

            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label htmlFor="real-time-sync" className="text-base">Real-time Sync</Label>
                <p className="text-sm text-muted-foreground">
                  Enable live data synchronization with weather stations
                </p>
              </div>
              <Switch id="real-time-sync" defaultChecked />
            </div>

            <div className="pt-4">
              <Button className="w-full bg-primary hover:bg-primary/90" onClick={handleSave}>
                <SettingsIcon className="mr-2 h-4 w-4" />
                Save All Settings
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
