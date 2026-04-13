import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/area_model.dart';

/// Circle uses finalRisk colour so GNN-refined risk is reflected on the map
CircleMarker buildRiskCircle(Area a) {
  return CircleMarker(
    point: a.center,
    useRadiusInMeter: true,
    radius: a.radiusMeters,
    color: a.finalRisk.color.withOpacity(.28),
    borderColor: a.finalRisk.color.withOpacity(.9),
    borderStrokeWidth: 2,
  );
}

Marker buildAreaDot(Area a) {
  return Marker(
    point: a.center,
    width: 12,
    height: 12,
    child: Container(
      decoration: BoxDecoration(
        color: a.finalRisk.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.2),
      ),
    ),
  );
}

Widget buildLegendCard() {
  Widget row(Color c, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Risk Levels',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 6),
      row(RiskLevel.severe.color,   RiskLevel.severe.label),
      row(RiskLevel.high.color,     RiskLevel.high.label),
      row(RiskLevel.moderate.color, RiskLevel.moderate.label),
      row(RiskLevel.safe.color,     RiskLevel.safe.label),
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.hub_rounded, size: 11, color: Color(0xFF6C63FF)),
          SizedBox(width: 4),
          Text('GNN-refined', style: TextStyle(fontSize: 11, color: Color(0xFF6C63FF))),
        ],
      ),
    ],
  );
}
