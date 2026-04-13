import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'area_model.dart';

class Report {
  final String id;
  final String? note;
  final LatLng location;
  final RiskLevel severity;
  final DateTime createdAt;
  final String? username;

  Report({
    required this.id,
    this.note,
    required this.location,
    required this.severity,
    required this.createdAt,
    this.username,
  });

  Map<String, dynamic> toMap() {
    return {
      'note':      note,
      'location':  GeoPoint(location.latitude, location.longitude),
      'severity':  severity.label,
      'createdAt': createdAt.toIso8601String(),
      'username':  username,
    };
  }

  factory Report.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final gp   = data['location'] as GeoPoint;
    return Report(
      id:        doc.id,
      note:      data['note'] as String?,
      location:  LatLng(gp.latitude, gp.longitude),
      severity:  _riskFromLabel(data['severity'] as String? ?? 'Safe'),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      username:  data['username'] as String?,
    );
  }

  static RiskLevel _riskFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'severe':   return RiskLevel.severe;
      case 'high':     return RiskLevel.high;
      case 'moderate': return RiskLevel.moderate;
      default:         return RiskLevel.safe;
    }
  }
}
