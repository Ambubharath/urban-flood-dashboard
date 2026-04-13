import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../services/routing_service.dart';
import '../services/data_service.dart';
import '../models/hazard_point.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_appbar.dart';

class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  final _destinationCtrl = TextEditingController();
  final _mapController = MapController();
  final _routingService = RoutingService();

  LatLng? _origin;
  LatLng? _destination;
  RouteResult? _result;
  List<HazardPoint> _hazards = [];

  bool _loadingLocation = false;
  bool _loadingRoute = false;
  bool _mapReady = false;

  String? _error;

  static const LatLng _fallback = LatLng(8.5241, 76.9366);

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _loadingLocation = true);

    try {
      final pos = await Geolocator.getCurrentPosition();
      _origin = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      _origin = _fallback;
      _error = "Using fallback location";
    }

    setState(() => _loadingLocation = false);
    _moveCamera();
  }

  void _moveCamera() {
    if (_mapReady && _origin != null) {
      _mapController.move(_origin!, 13);
    }
  }

  Future<void> _findRoute() async {
    final text = _destinationCtrl.text.trim();

    if (text.isEmpty) {
      setState(() => _error = "Enter destination");
      return;
    }

    setState(() {
      _loadingRoute = true;
      _error = null;
      _result = null;
      _destination = null;
    });

    try {
      final dest = await _routingService.geocode(text);

      if (dest == null) {
        setState(() => _error = "Location not found");
        return;
      }

      _destination = dest;

      final areas = context.read<DataService>().areas;
      final hazards = await _routingService.fetchHazardPoints(areas);

      final result = await _routingService.buildSafeRoute(
        origin: _origin!,
        destination: dest,
        hazards: hazards,
      );

      setState(() {
        _hazards = hazards;
        _result = result;
      });

      _fitRoute(result);
    } catch (_) {
      setState(() => _error = "Failed to get route");
    } finally {
      setState(() => _loadingRoute = false);
    }
  }

  void _fitRoute(RouteResult r) {
    if (r.polylinePoints.length < 2) return;

    final lats = r.polylinePoints.map((e) => e.latitude);
    final lngs = r.polylinePoints.map((e) => e.longitude);

    final bounds = LatLngBounds(
      LatLng(lats.reduce((a, b) => a < b ? a : b),
          lngs.reduce((a, b) => a < b ? a : b)),
      LatLng(lats.reduce((a, b) => a > b ? a : b),
          lngs.reduce((a, b) => a > b ? a : b)),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: "Safe Route",
        subtitle: "Flood-aware navigation",
      ),
      body: Column(
        children: [
          _SearchBar(
            controller: _destinationCtrl,
            isLoading: _loadingRoute,
            onSearch: _findRoute,
          ),

          // ✅ ROUTE MESSAGE (FIXED)
          if (_result != null) _RouteBanner(result: _result!),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),

          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _origin ?? _fallback,
                    initialZoom: 13,
                    onMapReady: () {
                      _mapReady = true;
                      _moveCamera();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),

                    if (_result != null &&
                        _result!.polylinePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _result!.polylinePoints,
                            strokeWidth: 5,
                            color: _result!.wasRerouted
                                ? Colors.green
                                : AppColors.primary,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          )
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        if (_origin != null)
                          Marker(
                            point: _origin!,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.my_location),
                          ),
                        if (_destination != null)
                          Marker(
                            point: _destination!,
                            width: 30,
                            height: 30,
                            child: const Icon(Icons.location_on,
                                color: Colors.red),
                          ),
                      ],
                    ),
                  ],
                ),

                if (_loadingLocation || _loadingRoute)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSearch;

  const _SearchBar({
    required this.controller,
    required this.isLoading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSearch(),
              decoration: const InputDecoration(
                hintText: "Enter destination",
              ),
            ),
          ),
          const SizedBox(width: 10),
          isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: onSearch,
                  child: const Icon(Icons.search),
                )
        ],
      ),
    );
  }
}

// ✅ IMPORTANT: THIS FIXES YOUR MISSING MESSAGE
class _RouteBanner extends StatelessWidget {
  final RouteResult result;

  const _RouteBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;

    if (result.wasRerouted) {
      text = "Safe route found (avoiding floods)";
      color = Colors.green;
    } else if (result.hazardsOnRoute.isNotEmpty) {
      text = "⚠️ Route passes through flood area";
      color = Colors.orange;
    } else {
      text = "Route is safe";
      color = Colors.blue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: color.withOpacity(0.15),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}