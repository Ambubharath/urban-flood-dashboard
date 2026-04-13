import { useEffect, useState, useCallback } from "react";
import DashboardStats from "@/components/dashboard/DashboardStats";
import RainfallChart from "@/components/dashboard/RainfallChart";
import FloodIntensityChart from "@/components/dashboard/FloodIntensityChart";
import FloodMap from "@/components/dashboard/FloodMap";
import GNNComparisonTable from "@/components/dashboard/GNNComparisonTable";
import { predictAllAreas, FullPipelineResult } from "@/lib/api";
import { RefreshCw, AlertTriangle, Wifi, WifiOff } from "lucide-react";

const OWM_KEY = "0234070d39f15419dcfe80aeeafaee06";
const TRIVANDRUM_LAT = 8.5241;
const TRIVANDRUM_LON = 76.9366;

type RainfallStatus = "loading" | "live" | "fallback" | "error";

interface RainfallInfo {
  value: number;
  status: RainfallStatus;
  source: string;
  rawResponse?: string;
}

async function fetchLiveRainfall(): Promise<RainfallInfo> {
  // Strategy 1: OWM One Call 3.0 (paid plan — daily forecast rain)
  try {
    const res = await fetch(
      `https://api.openweathermap.org/data/3.0/onecall` +
      `?lat=${TRIVANDRUM_LAT}&lon=${TRIVANDRUM_LON}` +
      `&exclude=current,minutely,hourly,alerts&units=metric&appid=${OWM_KEY}`
    );
    const data = await res.json();

    if (res.ok && data?.daily?.[0] !== undefined) {
      const todayRain = data.daily[0].rain ?? 0;
      return {
        value: todayRain,
        status: "live",
        source: "OWM One Call 3.0 (daily forecast)",
      };
    }
    // API returned error (e.g. 401 = not subscribed)
    console.warn("OWM 3.0 failed:", data?.message ?? res.status);
  } catch (e) {
    console.warn("OWM 3.0 network error:", e);
  }

  // Strategy 2: OWM Current Weather 2.5 (free plan — 1h rain)
  try {
    const res = await fetch(
      `https://api.openweathermap.org/data/2.5/weather` +
      `?lat=${TRIVANDRUM_LAT}&lon=${TRIVANDRUM_LON}&units=metric&appid=${OWM_KEY}`
    );
    const data = await res.json();

    if (res.ok && data?.main) {
      const rain1h = data?.rain?.["1h"] ?? 0;
      const rain3h = data?.rain?.["3h"] ?? 0;
      // Extrapolate to a rough daily estimate so LightGBM gets a meaningful input
      // (the model was trained on daily rainfall_mm, not hourly readings)
      const rainHourly = rain1h > 0 ? rain1h : rain3h / 3;
      const rainDailyEstimate = parseFloat((rainHourly * 24).toFixed(2));
      return {
        value: rainDailyEstimate,
        status: "live",
        source: `OWM Current Weather 2.5 (${rain1h > 0 ? "1h rain ×24" : rain3h > 0 ? "3h rain extrapolated" : "no rain detected"})`,
        rawResponse: JSON.stringify({ rain: data.rain, weather: data.weather?.[0]?.description }),
      };
    }
    console.warn("OWM 2.5 failed:", data?.message ?? res.status);
  } catch (e) {
    console.warn("OWM 2.5 network error:", e);
  }

  // Strategy 3: Zero fallback — clearly marked so the UI can show a warning
  return {
    value: 0,
    status: "fallback",
    source: "Both OWM endpoints failed — using 0 mm fallback",
  };
}

export default function Dashboard() {
  const [rainfallInfo, setRainfallInfo] = useState<RainfallInfo | null>(null);
  const [predictions, setPredictions] = useState<FullPipelineResult[] | null>(null);
  const [loadingPredictions, setLoadingPredictions] = useState(false);
  const [lastRefreshed, setLastRefreshed] = useState<Date | null>(null);

  const refresh = useCallback(async () => {
    // Step 1: Fetch rainfall
    setRainfallInfo(null);
    setPredictions(null);
    setLoadingPredictions(true);

    const info = await fetchLiveRainfall();
    setRainfallInfo(info);

    // Step 2: Fetch ALL predictions ONCE — pass down to all components
    try {
      const results = await predictAllAreas(info.value);
      setPredictions(results);
    } catch (e) {
      console.error("Prediction fetch failed:", e);
      setPredictions([]);
    } finally {
      setLoadingPredictions(false);
      setLastRefreshed(new Date());
    }
  }, []);

  useEffect(() => { refresh(); }, [refresh]);

  const rainfall = rainfallInfo?.value ?? null;

  return (
    <div className="space-y-6 animate-fade-in">
      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-foreground">Dashboard Overview</h1>
          <p className="text-muted-foreground mt-1">
            Real-time flood risk — Phase 1 (LightGBM) + Phase 2 (GNN)
          </p>
        </div>
        <button
          onClick={refresh}
          disabled={loadingPredictions || rainfallInfo === null}
          className="flex items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm text-muted-foreground hover:bg-muted transition-colors disabled:opacity-40"
        >
          <RefreshCw className={`h-4 w-4 ${loadingPredictions ? "animate-spin" : ""}`} />
          Refresh
        </button>
      </div>

      {/* Rainfall status banner */}
      <RainfallStatusBanner info={rainfallInfo} lastRefreshed={lastRefreshed} />

      <DashboardStats predictions={predictions} loadingPredictions={loadingPredictions} />

      <div className="grid gap-6 lg:grid-cols-2">
        <RainfallChart />
        <FloodIntensityChart predictions={predictions} />
      </div>

      <FloodMap rainfall={rainfall} predictions={predictions} />

      <GNNComparisonTable predictions={predictions} loadingPredictions={loadingPredictions} />
    </div>
  );
}

function RainfallStatusBanner({ info, lastRefreshed }: { info: RainfallInfo | null; lastRefreshed: Date | null }) {
  if (!info) {
    return (
      <div className="flex items-center gap-3 rounded-lg border border-border bg-muted/40 px-4 py-3 text-sm text-muted-foreground">
        <RefreshCw className="h-4 w-4 animate-spin" />
        Fetching live rainfall data…
      </div>
    );
  }

  const isLive = info.status === "live";
  const isFallback = info.status === "fallback";

  return (
    <div className={`flex flex-col gap-1 rounded-lg border px-4 py-3 text-sm ${
      isLive
        ? "border-green-200 bg-green-50 text-green-800"
        : "border-yellow-200 bg-yellow-50 text-yellow-800"
    }`}>
      <div className="flex items-center gap-3">
        {isLive
          ? <Wifi className="h-4 w-4 shrink-0" />
          : <WifiOff className="h-4 w-4 shrink-0" />
        }
        <span className="font-medium">
          {isLive
            ? `Live rainfall: ${info.value.toFixed(2)} mm — ${info.source}`
            : `Rainfall API unavailable — predictions are running with 0 mm input`
          }
        </span>
        {lastRefreshed && (
          <span className="ml-auto text-xs opacity-60">
            Updated {lastRefreshed.toLocaleTimeString()}
          </span>
        )}
      </div>
      {isFallback && (
        <div className="flex items-start gap-2 mt-1 text-xs text-yellow-700">
          <AlertTriangle className="h-3.5 w-3.5 mt-0.5 shrink-0" />
          <span>
            The OpenWeatherMap One Call 3.0 API requires a paid subscription. The free 2.5 endpoint also returned no data.
            Predictions below reflect baseline risk scores at 0 mm rainfall — areas showing Medium risk do so because the
            LightGBM model assigns them a non-zero baseline probability even without rainfall (based on historical patterns).
            This is expected behaviour, not an error.
          </span>
        </div>
      )}
      {info.rawResponse && isLive && (
        <div className="text-xs opacity-60 font-mono mt-1">{info.rawResponse}</div>
      )}
    </div>
  );
}
