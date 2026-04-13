import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_appbar.dart';
import '../services/data_service.dart';
import '../models/area_model.dart';
import '../utils/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DataService>();
    final allAreas = svc.areas;

    final filtered = allAreas.where((a) =>
        _searchQuery.isEmpty ||
        a.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: const CustomAppBar(
        title: 'FloodWatch',
        subtitle: 'Trivandrum Flood Monitor',
      ),
      body: SafeArea(
        child: svc.isLoading && allAreas.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => svc.fetchAreasFromApi(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  children: [
                    const _AlertSection(),
                    const SizedBox(height: 24),
                    _SearchField(controller: _searchController),
                    const SizedBox(height: 24),

                    // ── Summary chips ───────────────────────────
                    if (allAreas.isNotEmpty) _RiskSummaryRow(areas: allAreas),
                    const SizedBox(height: 24),

                    Text(
                      _searchQuery.isEmpty
                          ? 'Flood Risk Areas'
                          : 'Search Results (${filtered.length})',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall!
                          .copyWith(fontWeight: FontWeight.w800, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),

                    if (filtered.isEmpty && _searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'No results found for "$_searchQuery".',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                          ),
                        ),
                      ),

                    ...filtered.map((a) => _AreaCard(area: a)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Risk summary row (counts per level)
// ────────────────────────────────────────────────────────────────────────────
class _RiskSummaryRow extends StatelessWidget {
  final List<Area> areas;
  const _RiskSummaryRow({required this.areas});

  @override
  Widget build(BuildContext context) {
    int severe   = areas.where((a) => a.finalRisk == RiskLevel.severe).length;
    int high     = areas.where((a) => a.finalRisk == RiskLevel.high).length;
    int moderate = areas.where((a) => a.finalRisk == RiskLevel.moderate).length;
    int safe     = areas.where((a) => a.finalRisk == RiskLevel.safe).length;

    Widget chip(Color c, String label, int count) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: c)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: c)),
            ],
          ),
        );

    return Row(
      children: [
        Expanded(child: chip(AppColors.severe,   'Severe',   severe)),
        const SizedBox(width: 8),
        Expanded(child: chip(AppColors.high,     'High',     high)),
        const SizedBox(width: 8),
        Expanded(child: chip(AppColors.moderate, 'Moderate', moderate)),
        const SizedBox(width: 8),
        Expanded(child: chip(AppColors.safe,     'Safe',     safe)),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Alert banner (Firestore)
// ────────────────────────────────────────────────────────────────────────────
class _AlertSection extends StatelessWidget {
  const _AlertSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alerts')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final alert = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final title    = alert['title']      ?? 'New Alert';
        final message  = alert['message']    ?? 'Stay alert and follow safety measures.';
        final severity = alert['severity']   ?? 'Moderate';
        final area     = alert['targetArea'] ?? 'All Trivandrum Areas';

        Color bgColor, textColor;
        IconData icon;

        switch (severity.toLowerCase()) {
          case 'critical':
          case 'high':
            bgColor   = AppColors.severe.withOpacity(0.15);
            textColor = AppColors.severe;
            icon      = Icons.flash_on_rounded;
            break;
          case 'moderate':
            bgColor   = AppColors.moderate.withOpacity(0.15);
            textColor = AppColors.moderate;
            icon      = Icons.warning_amber_rounded;
            break;
          default:
            bgColor   = Colors.blue.shade100;
            textColor = Colors.blue.shade700;
            icon      = Icons.info_outline;
        }

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: textColor.withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: textColor, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: textColor)),
                    const SizedBox(height: 6),
                    Text(message,
                        style: const TextStyle(
                            color: Colors.black87, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Severity: $severity  •  Area: $area',
                        style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Search field
// ────────────────────────────────────────────────────────────────────────────
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      cursorColor: Theme.of(context).primaryColor,
      decoration: InputDecoration(
        hintText: 'Search locality...',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: controller.clear,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Theme.of(context).primaryColor, width: 2),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Area card — shows final GNN risk + score gauge
// ────────────────────────────────────────────────────────────────────────────
class _AreaCard extends StatelessWidget {
  final Area area;
  const _AreaCard({required this.area});

  Color get _riskColor => area.finalRisk.color;
  Color get _cardBg    => _riskColor.withOpacity(0.05);

  IconData get _riskIcon {
    switch (area.finalRisk) {
      case RiskLevel.severe:
        return Icons.warning_rounded;
      case RiskLevel.high:
        return Icons.water_damage_rounded;
      case RiskLevel.moderate:
        return Icons.water_drop_rounded;
      case RiskLevel.safe:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _riskColor.withOpacity(0.2), width: 1.5),
      ),
      color: _cardBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_riskIcon, color: _riskColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(area.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge!
                              .copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.black)),
                      const SizedBox(height: 4),
                      Text(
                        'Rainfall: ${area.rainfall.toStringAsFixed(1)} mm  •  '
                        'Pop: ${(area.population / 1000).toStringAsFixed(0)}k',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // ── Final risk badge ────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _riskColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    area.finalRisk.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Prediction score gauge ─────────────────────────
            _PredictionScoreBar(area: area),

            // ── 7-day forecast ─────────────────────────────────
            if (area.forecast.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('7-Day Rainfall Forecast (mm):',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black)),
              const SizedBox(height: 16),
              _ForecastChart(
                forecast: area.forecast.take(7).toList(),
                currentRainfall: area.rainfall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Prediction score bar — shows the final ML score with GNN badge
// ────────────────────────────────────────────────────────────────────────────
class _PredictionScoreBar extends StatelessWidget {
  final Area area;
  const _PredictionScoreBar({required this.area});

  String get _scoreLabel {
    if (area.predictionScore < 0) return '—';
    return '${(area.predictionScore * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = area.predictionScore >= 0;
    final score = hasScore ? area.predictionScore.clamp(0.0, 1.0) : 0.0;
    final barColor = area.finalRisk.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: barColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              const Text('Flood Risk Score',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              const Spacer(),
              // GNN badge
              if (area.isGnnRefined)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded,
                          size: 12, color: Color(0xFF6C63FF)),
                      SizedBox(width: 4),
                      Text('GNN',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6C63FF))),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text('Phase 1',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54)),
                ),
              const SizedBox(width: 10),
              Text(_scoreLabel,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: barColor)),
            ],
          ),
          const SizedBox(height: 10),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: hasScore ? score : 0,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 8),
          // Scale labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Low', style: TextStyle(fontSize: 11, color: Colors.black38)),
              Text('Medium', style: TextStyle(fontSize: 11, color: Colors.black38)),
              Text('High', style: TextStyle(fontSize: 11, color: Colors.black38)),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 7-day forecast bar chart (unchanged from original)
// ────────────────────────────────────────────────────────────────────────────
class _ForecastChart extends StatelessWidget {
  final List<double> forecast;
  final double currentRainfall;
  const _ForecastChart(
      {required this.forecast, required this.currentRainfall});

  static const double _maxRainfall = 50.0;
  static const double _barWidth    = 14;

  double _norm(double v) => (v / _maxRainfall).clamp(0.0, 1.0);

  Color _color(double v) {
    if (v > 40) return AppColors.severe;
    if (v > 20) return AppColors.moderate;
    if (v > 10) return Colors.lightBlue.shade700;
    return Colors.blue.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final data = List<double>.from(forecast);
    if (data.isNotEmpty) data[0] = currentRainfall;

    return SizedBox(
      height: 130,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          final barColor = _color(v);
          final isToday  = i == 0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(v.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday ? Colors.black : Colors.black87)),
              const SizedBox(height: 6),
              Container(
                height: 80,
                width: _barWidth,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(_barWidth / 2),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 80 * _norm(v),
                    width: _barWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [barColor, barColor.withOpacity(0.7)],
                      ),
                      borderRadius: BorderRadius.circular(_barWidth / 2),
                      boxShadow: [
                        BoxShadow(
                          color: barColor.withOpacity(0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isToday ? 'Today' : 'Day ${i + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isToday ? FontWeight.w800 : FontWeight.w500,
                  color: isToday ? Colors.black : Colors.black54,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
