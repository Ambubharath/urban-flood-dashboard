// src/pages/Reports.tsx
import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Search, CheckCircle, Clock } from "lucide-react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "@/lib/firebase";
import dayjs from "dayjs";
import relativeTime from "dayjs/plugin/relativeTime";

dayjs.extend(relativeTime);

interface Report {
  id: string;
  username?: string;
  location?: any; // Firestore GeoPoint
  createdAt?: string;
  severity?: string;
  status?: string;
  note?: string;
}

const getStatusBadge = (status?: string) => {
  switch (status) {
    case "pending":
      return <Badge variant="outline" className="bg-yellow-50 text-yellow-700 border-yellow-200"><Clock className="h-3 w-3 mr-1" />Pending</Badge>;
    case "verified":
      return <Badge variant="outline" className="bg-blue-50 text-blue-700 border-blue-200"><CheckCircle className="h-3 w-3 mr-1" />Verified</Badge>;
    case "resolved":
      return <Badge variant="outline" className="bg-green-50 text-green-700 border-green-200"><CheckCircle className="h-3 w-3 mr-1" />Resolved</Badge>;
    default:
      return <Badge variant="outline">Unknown</Badge>;
  }
};

const getSeverityBadge = (severity?: string) => {
  switch (severity?.toLowerCase()) {
    case "critical":
    case "severe":
      return <Badge className="bg-red-600 text-white">Critical</Badge>;
    case "high":
      return <Badge className="bg-orange-500 text-white">High</Badge>;
    case "moderate":
      return <Badge className="bg-yellow-500 text-white">Moderate</Badge>;
    case "low":
      return <Badge className="bg-green-500 text-white">Low</Badge>;
    default:
      return <Badge variant="secondary">Unknown</Badge>;
  }
};

export default function Reports() {
  const [reports, setReports] = useState<Report[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [filterStatus, setFilterStatus] = useState("all");

  // Fetch reports from Firebase
  useEffect(() => {
    const fetchReports = async () => {
      try {
        const querySnapshot = await getDocs(collection(db, "reports"));
        const data = querySnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        setReports(data as Report[]);
      } catch (err) {
        console.error("Error fetching reports:", err);
      }
    };

    fetchReports();
  }, []);

  // Filter and search
  const filteredReports = reports.filter((report) => {
    const matchesStatus = filterStatus === "all" || report.status === filterStatus;
    const matchesSearch =
      report.username?.toLowerCase().includes(searchTerm.toLowerCase()) ||
      report.note?.toLowerCase().includes(searchTerm.toLowerCase());
    return matchesStatus && matchesSearch;
  });

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div>
        <h1 className="text-3xl font-bold text-foreground">User Reports</h1>
        <p className="text-muted-foreground mt-1">Review and manage flood reports from citizens</p>
      </div>

      {/* Filters */}
      <Card className="card-shadow">
        <CardContent className="pt-6">
          <div className="flex flex-col gap-4 md:flex-row md:items-center">
            <div className="relative flex-1">
              <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search by username or note..."
                className="pl-10"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
              />
            </div>
            <Select value={filterStatus} onValueChange={setFilterStatus}>
              <SelectTrigger className="w-full md:w-[180px]">
                <SelectValue placeholder="Filter by status" />
              </SelectTrigger>
              <SelectContent className="bg-popover">
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="pending">Pending</SelectItem>
                <SelectItem value="verified">Verified</SelectItem>
                <SelectItem value="resolved">Resolved</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardContent>
      </Card>

      {/* Reports Table */}
      <Card className="card-shadow">
        <CardHeader>
          <CardTitle className="text-lg font-semibold">Recent Reports</CardTitle>
        </CardHeader>
        <CardContent>
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Username</TableHead>
                <TableHead>Location (Trivandrum)</TableHead>
                <TableHead>Time</TableHead>
                <TableHead>Severity</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Note</TableHead>
                <TableHead className="text-right">Actions</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {filteredReports.map((report) => {
                const lat = report.location?._lat ?? report.location?.latitude ?? null;
                const lng = report.location?._long ?? report.location?.longitude ?? null;

                return (
                  <TableRow key={report.id}>
                    <TableCell className="font-medium">{report.username || "Anonymous"}</TableCell>
                    <TableCell>
                      {lat !== null && lng !== null ? `${lat.toFixed(4)}, ${lng.toFixed(4)}` : "-"}
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {report.createdAt ? dayjs(report.createdAt).fromNow() : "-"}
                    </TableCell>
                    <TableCell>{getSeverityBadge(report.severity)}</TableCell>
                    <TableCell>{getStatusBadge(report.status)}</TableCell>
                    <TableCell>{report.note || "-"}</TableCell>
                    <TableCell className="text-right">
                      <Button variant="ghost" size="sm" className="hover:bg-accent">
                        View Details
                      </Button>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
      </Card>
    </div>
  );
}
