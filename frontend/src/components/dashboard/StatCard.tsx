import { LucideIcon } from "lucide-react";
import { ReactNode } from "react";
import { Card, CardContent } from "@/components/ui/card";

interface StatCardProps {
  title: string;
  value: string | ReactNode;
  icon: LucideIcon;
  color?: string;
}

export default function StatCard({ title, value, icon: Icon, color = "text-primary" }: StatCardProps) {
  return (
    <Card className="card-shadow">
      <CardContent className="flex items-center gap-4 p-6">
        <div className={`flex h-12 w-12 items-center justify-center rounded-lg bg-muted ${color}`}>
          <Icon className="h-6 w-6" />
        </div>
        <div>
          <p className="text-sm text-muted-foreground">{title}</p>
          <div className="text-3xl font-bold text-foreground leading-tight mt-1">{value}</div>
        </div>
      </CardContent>
    </Card>
  );
}
