import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Download } from "lucide-react";
import { 
  LineChart, Line, BarChart, Bar, PieChart, Pie, Cell,
  XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend 
} from "recharts";

const frequencyData = [
  { region: "Fort", floods: 18 },
  { region: "Karamana", floods: 22 },
  { region: "Pettah", floods: 15 },
  { region: "Vattiyoorkavu", floods: 12 },
  { region: "Medical College", floods: 14 },
  { region: "Pattom", floods: 11 },
  { region: "Ulloor", floods: 9 },
  { region: "Kazhakootam", floods: 6 },
];

const responseTimeData = [
  { month: "Jan", avgTime: 38 },
  { month: "Feb", avgTime: 35 },
  { month: "Mar", avgTime: 42 },
  { month: "Apr", avgTime: 32 },
  { month: "May", avgTime: 28 },
  { month: "Jun", avgTime: 25 },
];

const correlationData = [
  { month: "Jan", rainfall: 145, floods: 12 },
  { month: "Feb", rainfall: 120, floods: 9 },
  { month: "Mar", rainfall: 185, floods: 16 },
  { month: "Apr", rainfall: 220, floods: 20 },
  { month: "May", rainfall: 280, floods: 25 },
  { month: "Jun", rainfall: 310, floods: 28 },
];

const severityDistribution = [
  { name: "Critical", value: 22, color: "#ef4444" },
  { name: "High", value: 35, color: "#f97316" },
  { name: "Moderate", value: 28, color: "#eab308" },
  { name: "Low", value: 15, color: "#22c55e" },
];

export default function Analytics() {
  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Analytics - Trivandrum</h1>
          <p className="text-muted-foreground mt-1">Comprehensive flood data analysis across Trivandrum wards</p>
        </div>
        <Button className="bg-primary hover:bg-primary/90">
          <Download className="mr-2 h-4 w-4" />
          Export Report
        </Button>
      </div>

      {/* Charts Grid */}
      <div className="grid gap-6 lg:grid-cols-2">
        {/* Flood Frequency */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="text-lg font-semibold">Flood Frequency per Region</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={frequencyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis dataKey="region" stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <YAxis stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                <Bar dataKey="floods" fill="hsl(var(--primary))" radius={[8, 8, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Response Time */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="text-lg font-semibold">Average Response Time (minutes)</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={responseTimeData}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis dataKey="month" stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <YAxis stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                <Line type="monotone" dataKey="avgTime" stroke="hsl(var(--secondary))" strokeWidth={3} dot={{ fill: 'hsl(var(--secondary))', r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Rainfall vs Flood Correlation */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="text-lg font-semibold">Rainfall vs Flood Occurrence</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <LineChart data={correlationData}>
                <CartesianGrid strokeDasharray="3 3" stroke="hsl(var(--border))" />
                <XAxis dataKey="month" stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <YAxis stroke="hsl(var(--muted-foreground))" style={{ fontSize: '12px' }} />
                <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
                <Legend />
                <Line type="monotone" dataKey="rainfall" stroke="hsl(var(--primary))" strokeWidth={2} name="Rainfall (mm)" />
                <Line type="monotone" dataKey="floods" stroke="hsl(var(--destructive))" strokeWidth={2} name="Flood Events" />
              </LineChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Severity Distribution */}
        <Card className="card-shadow">
          <CardHeader>
            <CardTitle className="text-lg font-semibold">Severity Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={severityDistribution}
                  cx="50%"
                  cy="50%"
                  labelLine={false}
                  label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}
                  outerRadius={100}
                  fill="#8884d8"
                  dataKey="value"
                >
                  {severityDistribution.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ backgroundColor: 'hsl(var(--popover))', border: '1px solid hsl(var(--border))', borderRadius: '8px' }} />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
