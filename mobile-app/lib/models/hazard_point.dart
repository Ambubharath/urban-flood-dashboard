import 'package:latlong2/latlong.dart';

/// A single flood hazard location used by the routing service.
/// Sources: (1) user-submitted Firestore reports, (2) ML high-risk area centroids.
class HazardPoint {
  final LatLng location;
  final String severity;   // 'moderate' | 'high' | 'severe'
  final String source;     // 'report' | 'ml_model'
  final DateTime timestamp;
  final String? note;

  const HazardPoint({
    required this.location,
    required this.severity,
    required this.source,
    required this.timestamp,
    this.note,
  });

  /// Weight used when deciding how far to detour around this hazard.
  /// severe = 400 m buffer, high = 300 m, moderate = 200 m
  double get bufferMetres {
    switch (severity.toLowerCase()) {
      case 'severe': return 400;
      case 'high':   return 300;
      default:       return 200;
    }
  }
}
