import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result from the full GNN pipeline endpoint
class FullPredictionResult {
  final String place;
  final String phase1Label;   // LightGBM label
  final double phase1Score;   // High-risk probability
  final String finalLabel;    // GNN-refined final label
  final double predictionScore; // normalised 0-1 score for display
  final bool isGnnRefined;

  FullPredictionResult({
    required this.place,
    required this.phase1Label,
    required this.phase1Score,
    required this.finalLabel,
    required this.predictionScore,
    required this.isGnnRefined,
  });
}

/// Handles OpenWeather API + FastAPI (Phase-1 LightGBM + Phase-2 GNN)
class ApiService {
  final String weatherApiKey;
  final String fastApiBaseUrl;

  ApiService({
    required this.weatherApiKey,
    // Use 10.0.2.2 on Android emulator, 127.0.0.1 on web/desktop
    this.fastApiBaseUrl = 'http://10.0.2.2:8000',
  });

  // ────────────────────────────────────────────────────────────────
  // Weather: current 1-hour rainfall
  // ────────────────────────────────────────────────────────────────
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

  // ────────────────────────────────────────────────────────────────
  // Weather: 7-day daily rainfall forecast
  // ────────────────────────────────────────────────────────────────
  Future<List<double>> fetch7DayRainfall(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/3.0/onecall'
      '?lat=$lat&lon=$lon'
      '&exclude=current,minutely,hourly,alerts'
      '&appid=$weatherApiKey&units=metric',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['daily'] as List)
          .map<double>((d) => (d['rain'] as num?)?.toDouble() ?? 0.0)
          .toList();
    }
    throw Exception('Forecast API error: ${response.statusCode}');
  }

  // ────────────────────────────────────────────────────────────────
  // Prediction: full pipeline — Phase 1 + Phase 2 (GNN)
  // Returns the FINAL risk label (GNN-refined).
  // Falls back to Phase-1-only if the GNN endpoint is unavailable.
  // ────────────────────────────────────────────────────────────────
  Future<FullPredictionResult> predictRiskFull(
      String place, double rainfallMm) async {
    // ── Try full pipeline first ──────────────────────────────────
    try {
      final url = Uri.parse('$fastApiBaseUrl/predict-full/');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'place': place, 'rainfall_mm': rainfallMm}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final p1Label =
            (data['phase1']?['risk_label'] as String?) ?? 'Low';
        final p1Score =
            (data['phase1']?['risk_score'] as num?)?.toDouble() ?? 0.0;
        final finalLabel = (data['final_risk'] as String?) ?? p1Label;

        // Normalise GNN integer (0/1/2) or use phase1_score
        double score = p1Score;
        final gnnInt = data['phase2_gnn']?['risk_level_int'];
        if (gnnInt != null) score = (gnnInt as int) / 2.0;

        return FullPredictionResult(
          place: place,
          phase1Label: p1Label,
          phase1Score: p1Score,
          finalLabel: finalLabel,
          predictionScore: score.clamp(0.0, 1.0),
          isGnnRefined: true,
        );
      }
    } catch (_) {
      // GNN endpoint unavailable — fall through to Phase-1 only
    }

    // ── Fall back to Phase-1 only ────────────────────────────────
    final url = Uri.parse('$fastApiBaseUrl/predict/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'place': place, 'rainfall_mm': rainfallMm}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final label =
          (data['predicted_risk_label'] as String?) ?? 'Low';
      final score =
          (data['phase1_risk_score'] as num?)?.toDouble() ?? 0.0;
      return FullPredictionResult(
        place: place,
        phase1Label: label,
        phase1Score: score,
        finalLabel: label,
        predictionScore: score,
        isGnnRefined: false,
      );
    }

    throw Exception(
        'Both /predict-full/ and /predict/ failed: ${response.statusCode}');
  }
}
