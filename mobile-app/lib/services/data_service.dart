import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../models/area_model.dart';
import '../models/report_model.dart';

/// Centralised data manager — weather, predictions, Firestore reports
class DataService extends ChangeNotifier {
  final List<Area> _areas = [];
  List<Area> get areas => List.unmodifiable(_areas);

  bool isLoading = false;
  bool isApiData = false;

  final CollectionReference _reportCol =
      FirebaseFirestore.instance.collection('reports');

  final ApiService apiService = ApiService(
    weatherApiKey: '0234070d39f15419dcfe80aeeafaee06',
    fastApiBaseUrl: 'http://127.0.0.1:8000',
  );

  // ── Area definitions ────────────────────────────────────────────
  static const List<Map<String, dynamic>> _places = [
    {'id': 'chackai',       'name': 'Chackai',        'lat': 8.4812, 'lon': 76.9520, 'population': 30000, 'radius': 600},
    {'id': 'east_fort',     'name': 'East Fort',       'lat': 8.4927, 'lon': 76.9487, 'population': 25000, 'radius': 600},
    {'id': 'kazhakkoottam', 'name': 'Kazhakkoottam',  'lat': 8.5686, 'lon': 76.8731, 'population': 45500, 'radius': 700},
    {'id': 'manacaud',      'name': 'Manacaud',        'lat': 8.4715, 'lon': 76.9527, 'population': 28000, 'radius': 600},
    {'id': 'nalanchira',    'name': 'Nalanchira',      'lat': 8.5249, 'lon': 76.9181, 'population': 32000, 'radius': 650},
    {'id': 'pattom',        'name': 'Pattom',          'lat': 8.5156, 'lon': 76.9409, 'population': 36000, 'radius': 600},
    {'id': 'peroorkkada',   'name': 'Peroorkkada',     'lat': 8.5450, 'lon': 76.9650, 'population': 34000, 'radius': 650},
    {'id': 'petta',         'name': 'Petta',           'lat': 8.4873, 'lon': 76.9446, 'population': 21000, 'radius': 600},
    {'id': 'sreekaryam',    'name': 'Sreekaryam',      'lat': 8.5220, 'lon': 76.9270, 'population': 33000, 'radius': 700},
    {'id': 'thycaud',       'name': 'Thycaud',         'lat': 8.5061, 'lon': 76.9403, 'population': 29000, 'radius': 600},
    {'id': 'ulloor',        'name': 'Ulloor',          'lat': 8.5173, 'lon': 76.9491, 'population': 31000, 'radius': 650},
    {'id': 'vanchiyoor',    'name': 'Vanchiyoor',      'lat': 8.4940, 'lon': 76.9455, 'population': 28000, 'radius': 600},
    {'id': 'vattiyoorkavu', 'name': 'Vattiyoorkavu',  'lat': 8.5458, 'lon': 76.9675, 'population': 27000, 'radius': 650},
    {'id': 'vellayambalam', 'name': 'Vellayambalam',  'lat': 8.5005, 'lon': 76.9383, 'population': 26000, 'radius': 600},
  ];

  // ── Fetch all area data ─────────────────────────────────────────
  Future<void> fetchAreasFromApi() async {
    isLoading = true;
    notifyListeners();

    try {
      final List<Area> fetched = [];

      for (final place in _places) {
        try {
          // 1. 7-day rainfall forecast
          final weeklyRainfall = await apiService.fetch7DayRainfall(
            place['lat'] as double,
            place['lon'] as double,
          );

          final avgRainfall = weeklyRainfall.isNotEmpty
              ? weeklyRainfall.reduce((a, b) => a + b) / weeklyRainfall.length
              : 0.0;

          // 2. Full prediction — GNN-refined final risk
          final prediction = await apiService.predictRiskFull(
            place['name'] as String,
            avgRainfall,
          );

          final phase1Risk = _riskFromString(prediction.phase1Label);
          final finalRisk  = _riskFromString(prediction.finalLabel);

          final area = Area(
            id:            place['id'] as String,
            name:          place['name'] as String,
            center:        LatLng(place['lat'] as double, place['lon'] as double),
            radiusMeters:  (place['radius'] as int).toDouble(),
            population:    place['population'] as int,
            updatedAt:     DateTime.now(),
            risk:          phase1Risk,
            finalRisk:     finalRisk,
            predictionScore: prediction.predictionScore,
            isGnnRefined:  prediction.isGnnRefined,
            rainfall:      avgRainfall,
          )..forecast = weeklyRainfall;

          fetched.add(area);
        } catch (e) {
          debugPrint('⚠️ ${place['name']}: $e — using fallback');
          // Always add a fallback so the count stays at 14
          fetched.add(Area(
            id:           place['id'] as String,
            name:         place['name'] as String,
            center:       LatLng(place['lat'] as double, place['lon'] as double),
            radiusMeters: (place['radius'] as int).toDouble(),
            population:   place['population'] as int,
            updatedAt:    DateTime.now(),
            risk:         RiskLevel.safe,
            finalRisk:    RiskLevel.safe,
            predictionScore: -1,
            isGnnRefined: false,
            rainfall:     0.0,
          ));
        }
      }

      if (fetched.isNotEmpty) {
        _areas
          ..clear()
          ..addAll(fetched);
        isApiData = true;
      } else {
        _loadDummyData();
      }
    } catch (e) {
      debugPrint('❌ fetchAreasFromApi: $e');
      _loadDummyData();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Risk string → enum ──────────────────────────────────────────
  RiskLevel _riskFromString(String r) {
    switch (r.toLowerCase()) {
      case 'high':
        return RiskLevel.high;
      case 'medium':
      case 'moderate':
        return RiskLevel.moderate;
      case 'severe':
        return RiskLevel.severe;
      default:
        return RiskLevel.safe;
    }
  }

  // ── Dummy fallback ──────────────────────────────────────────────
  void _loadDummyData() {
    if (_areas.isNotEmpty) return;
    _areas.addAll([
      Area(
        id: 'chackai', name: 'Chackai',
        center: const LatLng(8.4812, 76.9520), radiusMeters: 600,
        population: 30000, rainfall: 12.0,
        updatedAt: DateTime.now(), risk: RiskLevel.high,
        finalRisk: RiskLevel.high, predictionScore: 0.75,
      )..forecast = [10, 12, 9, 8, 14, 7, 11],
      Area(
        id: 'kazhakkoottam', name: 'Kazhakkoottam',
        center: const LatLng(8.5686, 76.8731), radiusMeters: 700,
        population: 45500, rainfall: 10.0,
        updatedAt: DateTime.now(), risk: RiskLevel.moderate,
        finalRisk: RiskLevel.moderate, predictionScore: 0.5,
      )..forecast = [8, 9, 7, 11, 10, 13, 9],
      Area(
        id: 'vellayambalam', name: 'Vellayambalam',
        center: const LatLng(8.5005, 76.9383), radiusMeters: 600,
        population: 26000, rainfall: 5.0,
        updatedAt: DateTime.now(), risk: RiskLevel.safe,
        finalRisk: RiskLevel.safe, predictionScore: 0.1,
      )..forecast = [4, 5, 6, 4, 3, 5, 4],
    ]);
    isApiData = false;
  }

  // ── Reports ─────────────────────────────────────────────────────
  final List<Report> _reports = [];
  List<Report> get reports => List.unmodifiable(_reports);

  Future<void> addReport(Report r) async {
    _reports.add(r);
    notifyListeners();
    try {
      await _reportCol.doc(r.id).set(r.toMap());
    } catch (e) {
      debugPrint('⚠️ Report save error: $e');
    }
  }

  Future<List<Report>> fetchReportsFromFirebase() async {
    try {
      final snapshot = await _reportCol.get();
      return snapshot.docs.map((doc) => Report.fromSnapshot(doc)).toList();
    } catch (e) {
      debugPrint('⚠️ fetchReports: $e');
      return [];
    }
  }
}
