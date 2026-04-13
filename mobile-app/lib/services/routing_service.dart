import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../models/hazard_point.dart';
import '../models/area_model.dart';

class RouteResult {
  final List<LatLng> polylinePoints;
  final List<HazardPoint> hazardsOnRoute;
  final bool wasRerouted;
  final String summary;
  final double distanceKm;
  final int durationMinutes;

  const RouteResult({
    required this.polylinePoints,
    required this.hazardsOnRoute,
    required this.wasRerouted,
    required this.summary,
    required this.distanceKm,
    required this.durationMinutes,
  });
}

class RoutingService {

  // ✅ FIXED: GEOCODE METHOD (THIS WAS MISSING)
  Future<LatLng?> geocode(String place) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(place + ", Trivandrum, Kerala")}'
        '&format=json&limit=1',
      );

      final res = await http.get(url, headers: {
        'User-Agent': 'FloodWatchApp/1.0',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      }
    } catch (e) {
      debugPrint("Geocode error: $e");
    }
    return null;
  }

  Future<List<HazardPoint>> fetchHazardPoints(List<Area> areas) async {
    final hazards = <HazardPoint>[];

    for (final area in areas) {
      if (area.finalRisk == RiskLevel.severe) {
        hazards.add(HazardPoint(
          location: area.center,
          severity: 'severe',
          source: 'ml',
          timestamp: DateTime.now(),
        ));
      }
    }
    return hazards;
  }

  Future<RouteResult> buildSafeRoute({
    required LatLng origin,
    required LatLng destination,
    required List<HazardPoint> hazards,
  }) async {
    final direct = await _getRoute(origin, destination);

    if (direct == null) {
      throw Exception("Route not found");
    }

    final danger = _hazardsOnRoute(direct.polylinePoints, hazards);

    if (danger.isEmpty) {
      return RouteResult(
        polylinePoints: direct.polylinePoints,
        hazardsOnRoute: [],
        wasRerouted: false,
        summary: "Safe route",
        distanceKm: direct.distanceKm,
        durationMinutes: direct.durationMinutes,
      );
    }

    return RouteResult(
      polylinePoints: direct.polylinePoints,
      hazardsOnRoute: danger,
      wasRerouted: false,
      summary: "⚠️ Flood zone ahead",
      distanceKm: direct.distanceKm,
      durationMinutes: direct.durationMinutes,
    );
  }

  Future<_RawRoute?> _getRoute(LatLng origin, LatLng dest) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=polyline',
      );

      final res = await http.get(url);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final route = json['routes'][0];

        final points = _decode(route['geometry']);

        return _RawRoute(
          polylinePoints: points,
          distanceKm: route['distance'] / 1000,
          durationMinutes: (route['duration'] / 60).round(),
          summary: "OSRM",
        );
      }
    } catch (e) {
      debugPrint("Route error: $e");
    }
    return null;
  }

  List<LatLng> _decode(String encoded) {
    List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      final finalLat = lat / 1E5;
      final finalLng = lng / 1E5;

      // ✅ prevent infinite lines
      if (finalLat > 7 && finalLat < 13 && finalLng > 74 && finalLng < 78) {
        points.add(LatLng(finalLat, finalLng));
      }
    }

    return points;
  }

  List<HazardPoint> _hazardsOnRoute(
      List<LatLng> route, List<HazardPoint> hazards) {
    final result = <HazardPoint>[];

    for (final h in hazards) {
      for (final pt in route) {
        if (_distance(pt, h.location) < 150) {
          result.add(h);
          break;
        }
      }
    }
    return result;
  }

  double _distance(LatLng a, LatLng b) {
    const r = 6371000;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;

    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;

    final a1 = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return r * 2 * math.atan2(math.sqrt(a1), math.sqrt(1 - a1));
  }
}

class _RawRoute {
  final List<LatLng> polylinePoints;
  final double distanceKm;
  final int durationMinutes;
  final String summary;

  const _RawRoute({
    required this.polylinePoints,
    required this.distanceKm,
    required this.durationMinutes,
    required this.summary,
  });
}