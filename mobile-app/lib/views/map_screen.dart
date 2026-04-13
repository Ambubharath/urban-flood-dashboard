import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/custom_appbar.dart';
import '../widgets/risk_circle.dart';
import '../services/data_service.dart';
import '../models/area_model.dart';
import '../utils/app_colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  static const LatLng _initial = LatLng(8.5100, 76.9366);
  Area? _selectedArea;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();

    // Use finalRisk for the map circles so the colour reflects GNN output
    final circles   = data.areas.map((a) => buildRiskCircle(a)).toList();
    final markers   = data.areas.map((a) => _buildTapMarker(a)).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: const CustomAppBar(
        title: 'Flood Risk Map',
        subtitle: 'Trivandrum Flood Monitor',
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initial,
              initialZoom: 11.4,
              onTap: (_, __) => setState(() => _selectedArea = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.floodwatchapp',
              ),
              CircleLayer(circles: circles.cast<CircleMarker>()),
              MarkerLayer(markers: markers.cast<Marker>()),
            ],
          ),

          // ── Legend ──────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.93),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6)
                ],
              ),
              child: buildLegendCard(),
            ),
          ),

          // ── Area detail sheet (tap a circle) ────────────────
          if (_selectedArea != null)
            Positioned(
              bottom: 90,
              left: 16,
              right: 16,
              child: _AreaDetailSheet(
                area: _selectedArea!,
                onClose: () => setState(() => _selectedArea = null),
              ),
            ),

          // ── My location FAB ──────────────────────────────────
          Positioned(
            bottom: 28,
            right: 20,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              onPressed: _goToMyLocation,
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: const Text('My location',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // Build a tappable dot marker — tapping shows the area detail sheet
  Marker _buildTapMarker(Area area) {
    return Marker(
      point: area.center,
      width: 32,
      height: 32,
      child: GestureDetector(
        onTap: () => setState(() => _selectedArea = area),
        child: Container(
          decoration: BoxDecoration(
            color: area.finalRisk.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                  color: area.finalRisk.color.withOpacity(0.4),
                  blurRadius: 6)
            ],
          ),
          child: const Icon(Icons.location_pin,
              color: Colors.white, size: 16),
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')));
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions denied.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Location permissions permanently denied. Enable in settings.')));
      }
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    _mapController.move(LatLng(pos.latitude, pos.longitude), 14.5);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Centered to your location.')));
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Area detail sheet — shown when a marker is tapped
// ────────────────────────────────────────────────────────────────────────────
class _AreaDetailSheet extends StatelessWidget {
  final Area area;
  final VoidCallback onClose;
  const _AreaDetailSheet({required this.area, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final color  = area.finalRisk.color;
    final score  = area.predictionScore >= 0
        ? '${(area.predictionScore * 100).round()}%'
        : '—';

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(area.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, color: Colors.black38),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                _stat('Final Risk', area.finalRisk.label, color),
                const SizedBox(width: 12),
                _stat('Score', score, color),
                const SizedBox(width: 12),
                _stat('Rainfall', '${area.rainfall.toStringAsFixed(1)} mm',
                    AppColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            // Score bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: area.predictionScore >= 0
                    ? area.predictionScore.clamp(0.0, 1.0)
                    : 0,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            if (area.isGnnRefined) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.hub_rounded, size: 13, color: Color(0xFF6C63FF)),
                  SizedBox(width: 4),
                  Text('Spatially refined by GNN',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: Colors.black45)),
          ],
        ),
      ),
    );
  }
}
