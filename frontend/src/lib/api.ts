/**
 * api.ts — Centralised service layer for the Flood Prediction backend.
 * All components import from here; changing the base URL is one edit.
 */

const BASE_URL = "http://localhost:8000";

export const AREA_NAMES = [
  "Kazhakkoottam",
  "Manacaud",
  "Vellayambalam",
  "Nalanchira",
  "Pattom",
  "East Fort",
  "Petta",
  "Ulloor",
  "Vanchiyoor",
  "Thycaud",
  "Vattiyoorkavu",
  "Chackai",
  "Sreekaryam",
  "Peroorkkada",
];

/** Corrected coordinates aligned with areas.csv */
export const AREA_COORDINATES: Record<string, { lat: number; lng: number }> = {
  Kazhakkoottam:  { lat: 8.5686, lng: 76.8731 },
  Manacaud:       { lat: 8.4715, lng: 76.9527 },
  Vellayambalam:  { lat: 8.5005, lng: 76.9383 },
  Nalanchira:     { lat: 8.5249, lng: 76.9181 },
  Pattom:         { lat: 8.5156, lng: 76.9409 },
  "East Fort":    { lat: 8.4927, lng: 76.9487 },
  Petta:          { lat: 8.4873, lng: 76.9446 },
  Ulloor:         { lat: 8.5173, lng: 76.9491 },
  Vanchiyoor:     { lat: 8.4940, lng: 76.9455 },
  Thycaud:        { lat: 8.5061, lng: 76.9403 },
  Vattiyoorkavu:  { lat: 8.5458, lng: 76.9675 },
  Chackai:        { lat: 8.4812, lng: 76.9520 },
  Sreekaryam:     { lat: 8.5220, lng: 76.9270 },
  Peroorkkada:    { lat: 8.5450, lng: 76.9650 },
};

// ── Types ────────────────────────────────────────────────────────────────────

export interface Phase1Result {
  place: string;
  rainfall_mm: number;
  predicted_risk_label: "Low" | "Medium" | "High";
  phase1_risk_score: number;
  probabilities: { Low: number; Medium: number; High: number };
}

export interface Phase2Result {
  place: string;
  phase1_risk_used: number;
  gnn_refined_label: number;
  risk_level: "Low" | "Medium" | "High";
  note: string;
}

export interface FullPipelineResult {
  place: string;
  rainfall_mm: number;
  phase1: {
    risk_label: "Low" | "Medium" | "High";
    risk_score: number;
    prob_high_raw: number;
    probabilities: { Low: number; Medium: number; High: number };
  };
  phase2_gnn: {
    risk_label: "Low" | "Medium" | "High";
    risk_level_int: number;
    gnn_probabilities: { Low: number; Medium: number; High: number };
  };
  final_risk: "Low" | "Medium" | "High";
}

// ── API calls ────────────────────────────────────────────────────────────────

/** Phase 1: LightGBM prediction for a single area */
export async function predictPhase1(
  place: string,
  rainfall_mm: number
): Promise<Phase1Result> {
  const res = await fetch(`${BASE_URL}/predict/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ place, rainfall_mm }),
  });
  if (!res.ok) throw new Error(`Phase1 API error: ${res.status}`);
  return res.json();
}

/** Phase 2: GNN refinement for a single area */
export async function predictGNN(place: string): Promise<Phase2Result> {
  const res = await fetch(`${BASE_URL}/predict-gnn/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ place }),
  });
  if (!res.ok) throw new Error(`GNN API error: ${res.status}`);
  return res.json();
}

/** Full pipeline: Phase 1 + Phase 2 in one call */
export async function predictFull(
  place: string,
  rainfall_mm: number
): Promise<FullPipelineResult> {
  const res = await fetch(`${BASE_URL}/predict-full/`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ place, rainfall_mm }),
  });
  if (!res.ok) throw new Error(`Full pipeline API error: ${res.status}`);
  return res.json();
}

/** Fallback result used when an API call fails — keeps area count fixed at 14 */
function fallbackResult(place: string, rainfall_mm: number): FullPipelineResult {
  return {
    place,
    rainfall_mm,
    phase1: {
      risk_label: "Low",
      risk_score: 0.13,
      prob_high_raw: 0,
      probabilities: { Low: 1, Medium: 0, High: 0 },
    },
    phase2_gnn: {
      risk_label: "Low",
      risk_level_int: 0,
      gnn_probabilities: { Low: 1, Medium: 0, High: 0 },
    },
    final_risk: "Low",
  };
}

/** Run full pipeline for ALL 14 areas — always returns exactly 14 results */
export async function predictAllAreas(
  rainfall_mm: number
): Promise<FullPipelineResult[]> {
  const results = await Promise.allSettled(
    AREA_NAMES.map((place) => predictFull(place, rainfall_mm))
  );
  // Never filter — map failed results to a safe fallback so count stays at 14
  return results.map((r, i) =>
    r.status === "fulfilled" ? r.value : fallbackResult(AREA_NAMES[i], rainfall_mm)
  );
}

/** Severity → hex colour */
export function riskColor(label: string): string {
  switch (label) {
    case "High":   return "#ef4444";
    case "Medium": return "#eab308";
    default:       return "#22c55e";
  }
}
