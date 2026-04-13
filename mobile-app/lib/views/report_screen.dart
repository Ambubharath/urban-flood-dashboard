import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import '../utils/app_colors.dart';
import '../services/data_service.dart';
import '../models/report_model.dart';
import '../models/area_model.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _descCtrl = TextEditingController();
  RiskLevel _severity = RiskLevel.moderate;

  LatLng? _location;
  bool _fetchingGps = false;
  bool _submitting  = false;
  String? _gpsError;

  @override
  void initState() {
    super.initState();
    _captureGPS();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Auto-capture GPS on open ──────────────────────────────────────────────
  Future<void> _captureGPS() async {
    setState(() { _fetchingGps = true; _gpsError = null; });
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) throw Exception('Location services disabled.');

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw Exception('Location permission denied.');
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _location = LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      setState(() {
        _gpsError = e.toString();
        // Fallback to city centre so the user can still submit
        _location = const LatLng(8.4871, 76.9520);
      });
    } finally {
      setState(() => _fetchingGps = false);
    }
  }

  // ── Submit report ─────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Still acquiring location…')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final svc = context.read<DataService>();
      final r = Report(
        id:        DateTime.now().millisecondsSinceEpoch.toString(),
        note:      _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        location:  _location!,
        severity:  _severity,
        createdAt: DateTime.now(),
      );
      await svc.addReport(r);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted — thank you!'),
            backgroundColor: Colors.green,
          ),
        );
        _descCtrl.clear();
        setState(() => _severity = RiskLevel.moderate);
        // Re-capture GPS for next report
        _captureGPS();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Report Flood Incident'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          // ── Location card ────────────────────────────────────────────
          _sectionLabel('Your Location'),
          const SizedBox(height: 8),
          _LocationCard(
            location:    _location,
            isFetching:  _fetchingGps,
            error:       _gpsError,
            onRetry:     _captureGPS,
          ),

          const SizedBox(height: 20),

          // ── Description ───────────────────────────────────────────────
          _sectionLabel('Description (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines:   4,
            decoration: InputDecoration(
              hintText:  'e.g. Road completely flooded near the bus stop',
              filled:    true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 20),

          // ── Severity ──────────────────────────────────────────────────
          _sectionLabel('Severity'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _chip(RiskLevel.moderate),
              _chip(RiskLevel.high),
              _chip(RiskLevel.severe),
              _chip(RiskLevel.safe),
            ],
          ),

          const SizedBox(height: 32),

          // ── Submit ────────────────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: (_submitting || _fetchingGps) ? null : _submit,
            icon:  _submitting
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Icon(Icons.send),
            label: Text(_submitting ? 'Submitting…' : 'Submit Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16));

  Widget _chip(RiskLevel level) {
    final selected = _severity == level;
    return GestureDetector(
      onTap: () => setState(() => _severity = level),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [
                  level.color.withOpacity(.7),
                  level.color.withOpacity(.5)
                ])
              : null,
          color: selected ? null : level.color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: level.color.withOpacity(selected ? .7 : .3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: level.color),
            const SizedBox(width: 8),
            Text(level.label,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }
}

// ── Location card — shows map preview when GPS is ready ──────────────────────
class _LocationCard extends StatelessWidget {
  final LatLng? location;
  final bool isFetching;
  final String? error;
  final VoidCallback onRetry;

  const _LocationCard({
    required this.location,
    required this.isFetching,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.hardEdge,
      child: isFetching
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Getting your location…',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            )
          : location == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_off,
                          color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text(error ?? 'Location unavailable',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    // Mini map
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: location!,
                        initialZoom:   15,
                        interactionOptions:
                            const InteractionOptions(flags: InteractiveFlag.none),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.floodwatchapp',
                        ),
                        MarkerLayer(markers: [
                          Marker(
                            point:  location!,
                            width:  36,
                            height: 36,
                            child: const Icon(Icons.location_pin,
                                color: Colors.red, size: 36),
                          ),
                        ]),
                      ],
                    ),
                    // Coords overlay
                    Positioned(
                      bottom: 0,
                      left:   0,
                      right:  0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        color: Colors.black.withOpacity(0.55),
                        child: Text(
                          '${location!.latitude.toStringAsFixed(5)}, '
                          '${location!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
