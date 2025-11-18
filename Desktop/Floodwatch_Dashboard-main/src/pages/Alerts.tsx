import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Bell, Send, CheckCircle2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

// ✅ Import Firestore from your firebase.ts
import { db } from "@/lib/firebase";
import { collection, addDoc, serverTimestamp } from "firebase/firestore";

const alertHistory = [
  {
    id: "1",
    title: "Critical Flood Warning - Fort & Karamana",
    message:
      "Severe flooding detected near Fort area and Karamana River. Water level exceeding danger mark. Evacuate low-lying areas immediately.",
    timestamp: "45 min ago",
    status: "sent",
    severity: "critical",
  },
  {
    id: "2",
    title: "High Water Level Alert - Pettah Market Area",
    message:
      "Water levels rising rapidly in Pettah market district. Merchants advised to move goods to higher ground.",
    timestamp: "2 hours ago",
    status: "sent",
    severity: "high",
  },
  {
    id: "3",
    title: "Flood Advisory - Vattiyoorkavu & Medical College",
    message:
      "Heavy rainfall continuing. Residents in Vattiyoorkavu and Medical College areas should remain vigilant and avoid travel if possible.",
    timestamp: "4 hours ago",
    status: "sent",
    severity: "high",
  },
  {
    id: "4",
    title: "Weather Update - Trivandrum District",
    message:
      "IMD forecasts heavy to very heavy rainfall in Trivandrum for next 24 hours. All citizens advised to stay alert and follow safety guidelines.",
    timestamp: "6 hours ago",
    status: "sent",
    severity: "moderate",
  },
];

export default function Alerts() {
  const { toast } = useToast();
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [severity, setSeverity] = useState("moderate");
  const [targetArea, setTargetArea] = useState("all");

  // ✅ Send alert to Firestore
  const handleSendAlert = async () => {
    if (!title || !message) {
      toast({
        title: "Missing Information",
        description: "Please fill in all required fields",
        variant: "destructive",
      });
      return;
    }

    try {
      await addDoc(collection(db, "alerts"), {
        title,
        message,
        severity,
        targetArea,
        timestamp: serverTimestamp(),
        status: "sent",
      });

      toast({
        title: "✅ Alert Sent Successfully",
        description: "Your alert has been sent to all users in the selected area",
      });

      // Reset form
      setTitle("");
      setMessage("");
      setSeverity("moderate");
      setTargetArea("all");
    } catch (error) {
      console.error("Error sending alert:", error);
      toast({
        title: "Error Sending Alert",
        description: "Something went wrong while sending the alert",
        variant: "destructive",
      });
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case "critical":
        return "bg-destructive text-destructive-foreground";
      case "high":
        return "bg-orange-500 text-white";
      case "moderate":
        return "bg-yellow-500 text-white";
      default:
        return "bg-secondary text-secondary-foreground";
    }
  };

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">Alerts & Notifications</h1>
        <p className="text-muted-foreground mt-1">
          Create and manage flood alerts for citizens
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        {/* Create Alert Form */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Bell className="h-5 w-5 text-primary" />
              Create New Alert
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="title">Alert Title</Label>
              <Input
                id="title"
                placeholder="e.g., Critical Flood Warning"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>

            <div className="space-y-2">
              <Label htmlFor="message">Message</Label>
              <Textarea
                id="message"
                placeholder="Enter your alert message here..."
                rows={4}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="severity">Severity Level</Label>
                <Select value={severity} onValueChange={setSeverity}>
                  <SelectTrigger id="severity">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="bg-popover">
                    <SelectItem value="critical">Critical</SelectItem>
                    <SelectItem value="high">High</SelectItem>
                    <SelectItem value="moderate">Moderate</SelectItem>
                    <SelectItem value="low">Low</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label htmlFor="area">Target Area</Label>
                <Select value={targetArea} onValueChange={setTargetArea}>
                  <SelectTrigger id="area">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="bg-popover">
                    <SelectItem value="all">All Trivandrum Areas</SelectItem>
                    <SelectItem value="fort">Fort</SelectItem>
                    <SelectItem value="pettah">Pettah</SelectItem>
                    <SelectItem value="karamana">Karamana</SelectItem>
                    <SelectItem value="vattiyoorkavu">Vattiyoorkavu</SelectItem>
                    <SelectItem value="medical">Medical College</SelectItem>
                    <SelectItem value="pattom">Pattom</SelectItem>
                    <SelectItem value="ulloor">Ulloor</SelectItem>
                    <SelectItem value="kazhakootam">Kazhakootam</SelectItem>
                    <SelectItem value="sasthamangalam">Sasthamangalam</SelectItem>
                    <SelectItem value="thampanoor">Thampanoor</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <Button
              className="w-full bg-primary hover:bg-primary/90"
              onClick={handleSendAlert}
            >
              <Send className="mr-2 h-4 w-4" />
              Send Alert
            </Button>
          </CardContent>
        </Card>

        {/* Alert History */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CheckCircle2 className="h-5 w-5 text-primary" />
              Recent Alerts
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {alertHistory.map((alert) => (
                <div
                  key={alert.id}
                  className="rounded-lg border border-border p-4 transition-all hover:shadow-md"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div className="flex-1">
                      <h4 className="font-semibold text-foreground">
                        {alert.title}
                      </h4>
                      <p className="mt-1 text-sm text-muted-foreground">
                        {alert.message}
                      </p>
                      <p className="mt-2 text-xs text-muted-foreground">
                        {alert.timestamp}
                      </p>
                    </div>
                    <Badge className={getSeverityColor(alert.severity)}>
                      {alert.severity}
                    </Badge>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
