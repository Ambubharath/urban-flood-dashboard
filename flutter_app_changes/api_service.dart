import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result from the full GNN pipeline endpoint
class FullPredictionResult {
  final String place;
  final String phase1Label;
  final double phase1Score;
  final String finalLabel;
  final double predictionScore;   // 0–1 normalised score for progress bar
  final bool isGnnRefined;

  // GNN class probabilities (Low / Medium / High) — shown in detail view
  final double gnnProbLow;
  final double gnnProbMedium;
  final double gnnProbHigh;

  FullPredictionResult({
    required this.place,
    required this.phase1Label,
    required this.phase1Score,
    required this.finalLabel,
    required this.predictionScore,
    required this.isGnnRefined,
    this.gnnProbLow    = 0.0,
    this.gnnProbMedium = 0.0,
    this.gnnProbHigh   = 0.0,
  });
}

/// Handles OpenWeather API + FastAPI (Phase-1 LightGBM + Phase-2 GNN)
class ApiService {
  final String weatherApiKey;
  final String fastApiBaseUrl;

  ApiService({
    required this.weatherApiKey,
    this.fastApiBaseUrl = 'http://10.0.2.2:8000',
  });

  // ── Weather: current 1-hour rainfall ────────────────────────────────────
  Future<double> fetchRainfall(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['rain']?['1h'] as num?)?.toDouble() ?? 0.0;
    }
    throw Exception('Weather API error: ${response.statusCode}');
  }

  // ── Weather: 7-day daily rainfall forecast ───────────────────────────────
  Future<List<double>> fetch7DayRainfall(double lat, double lon) async {
    // Try One Call 3.0 first (paid), fall back to 2.5 current weather
    try {
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall'
        '?lat=$lat&lon=$lon'
        '&exclude=current,minutely,hourly,alerts'
        '&appid=$weatherApiKey&units=metric',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['daily'] != null) {
          return (data['daily'] as List)
              .map<double>((d) => (d['rain'] as num?)?.toDouble() ?? 0.0)
              .toList();
        }
      }
    } catch (_) {}

    // Fallback: return 7 identical values from current weather
    try {
      final rain = await fetchRainfall(lat, lon);
      return List.filled(7, rain);
    } catch (_) {
      return List.filled(7, 0.0);
    }
  }

  // ── Full pipeline: Phase 1 (LightGBM) + Phase 2 (GNN) ──────────────────
  // Falls back to Phase-1 only if GNN endpoint is unavailable.
  Future<FullPredictionResult> predictRiskFull(
      String place, double rainfallMm) async {

    // ── Try full pipeline first ──────────────────────────────────────────
    try {
      final url = Uri.parse('$fastApiBaseUrl/predict-full/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'place': place, 'rainfall_mm': rainfallMm}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final p1Label  = (data['phase1']?['risk_label']  as String?) ?? 'Low';
        final p1Score  = (data['phase1']?['risk_score']  as num?)?.toDouble() ?? 0.0;
        final finalLbl = (data['final_risk'] as String?) ?? p1Label;

        // GNN risk_level_int: 0=Low, 1=Medium, 2=High — normalise to 0–1
        final gnnInt   = (data['phase2_gnn']?['risk_level_int'] as int?);
        double score   = gnnInt != null ? gnnInt / 2.0 : p1Score;

        // Pull GNN probabilities (new field in v3)
        final gnnProbs = data['phase2_gnn']?['gnn_probabilities']
            as Map<String, dynamic>?;
        final pLow    = (gnnProbs?['Low']    as num?)?.toDouble() ?? 0.0;
        final pMed    = (gnnProbs?['Medium'] as num?)?.toDouble() ?? 0.0;
        final pHigh   = (gnnProbs?['High']   as num?)?.toDouble() ?? 0.0;

        return FullPredictionResult(
          place:          place,
          phase1Label:    p1Label,
          phase1Score:    p1Score,
          finalLabel:     finalLbl,
          predictionScore: score.clamp(0.0, 1.0),
          isGnnRefined:   true,
          gnnProbLow:     pLow,
          gnnProbMedium:  pMed,
          gnnProbHigh:    pHigh,
        );
      }
    } catch (_) {
      // GNN endpoint unavailable — fall through to Phase-1 only
    }

    // ── Phase-1 only fallback ────────────────────────────────────────────
    final url = Uri.parse('$fastApiBaseUrl/predict/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'place': place, 'rainfall_mm': rainfallMm}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data  = jsonDecode(response.body) as Map<String, dynamic>;
      final label = (data['predicted_risk_label'] as String?) ?? 'Low';
      final score = (data['phase1_risk_score']    as num?)?.toDouble() ?? 0.0;
      return FullPredictionResult(
        place:           place,
        phase1Label:     label,
        phase1Score:     score,
        finalLabel:      label,
        predictionScore: score.clamp(0.0, 1.0),
        isGnnRefined:    false,
      );
    }

    throw Exception(
        'Both /predict-full/ and /predict/ failed for $place: '
        '${response.statusCode}');
  }
}
