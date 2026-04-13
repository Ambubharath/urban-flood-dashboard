// lib/models/flood_risk_area.dart

class FloodRiskArea {
  final String locality;
  final String riskLevel;
  final double latitude;
  final double longitude;
  final String id; // Unique ID from API

  FloodRiskArea({
    required this.id,
    required this.locality,
    required this.riskLevel,
    required this.latitude,
    required this.longitude,
  });

  // Factory constructor to create a FloodRiskArea from a JSON map
  factory FloodRiskArea.fromJson(Map<String, dynamic> json) {
    return FloodRiskArea(
      id: json['id'] as String,
      locality: json['locality'] as String,
      riskLevel: json['risk_level'] as String, // e.g., 'Severe', 'High', 'Moderate', 'Safe'
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }
}