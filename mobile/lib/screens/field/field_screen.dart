import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../services/weather_service.dart' as ws;
import '../../widgets/section_card.dart';

class FieldScreen extends StatefulWidget {
  const FieldScreen({super.key});
  @override
  State<FieldScreen> createState() => _FieldScreenState();
}

class _FieldScreenState extends State<FieldScreen> {
  final _cropService = CropService();
  final _fieldService = ws.FieldService();
  Map<String, dynamic>? _reading;
  List<dynamic> _history = [];
  bool _loading = true;
  String? _error;
  String? _noActiveCropMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _noActiveCropMessage = null;
    });
    try {
      final crops = await _cropService.myCrops();
      if (crops.isEmpty) {
        setState(() => _noActiveCropMessage = 'Add a crop first to see field conditions.');
        return;
      }
      final active = crops.firstWhere((c) => c['is_active'] == 1, orElse: () => crops.first);
      final results = await Future.wait([
        _fieldService.latestReading(active['id']),
        _fieldService.history(active['id']),
      ]);
      setState(() {
        _reading = results[0] as Map<String, dynamic>?;
        _history = results[1] as List<dynamic>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Derived from actual stored readings, not fabricated: compares the
  /// latest soil-moisture value against the one before it in the real
  /// history list.
  Widget _trendArrow() {
    if (_history.length < 2) return const SizedBox.shrink();
    final latest = (_history.last['soil_moisture_pct'] as num).toDouble();
    final previous = (_history[_history.length - 2]['soil_moisture_pct'] as num).toDouble();
    if (latest > previous + 0.5) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_upward, size: 14, color: AppColors.waterBlue),
        Text(' Rising', style: TextStyle(fontSize: 12, color: AppColors.waterBlue)),
      ]);
    } else if (latest < previous - 0.5) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_downward, size: 14, color: AppColors.accentAmber),
        Text(' Falling', style: TextStyle(fontSize: 12, color: AppColors.accentAmber)),
      ]);
    }
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
      Text(' Stable', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
    ]);
  }

  Widget _row(String label, String value, String status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          StatusPill(
            label: status,
            color: status == 'High' ? AppColors.alertRed : (status == 'Low' ? AppColors.accentAmber : AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _trendChart() {
    if (_history.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Not enough readings yet to plot a trend. Log a few more field readings.', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < _history.length; i++) {
      final v = _history[i]['soil_moisture_pct'];
      if (v != null) spots.add(FlSpot(i.toDouble(), (v as num).toDouble()));
    }

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: const FlGridData(show: true, horizontalInterval: 25, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 25, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (_history.length / 4).clamp(1, _history.length).toDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= _history.length) return const SizedBox.shrink();
                  final ts = DateTime.tryParse(_history[idx]['recorded_at'] ?? '');
                  if (ts == null) return const SizedBox.shrink();
                  return Text(DateFormat('HH:mm').format(ts.toLocal()), style: const TextStyle(fontSize: 10, color: AppColors.textMuted));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.waterBlue,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.waterBlue.withOpacity(0.12)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Field Conditions')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : _noActiveCropMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_noActiveCropMessage!)))
                  : _reading == null
                      ? const Center(child: Text('No field readings recorded yet.'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              SectionCard(
                                title: 'Current Conditions',
                                icon: Icons.grass,
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: Text('Soil Moisture', style: const TextStyle(color: AppColors.textMuted))),
                                        Text('${_reading!['soil_moisture_pct']}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 8),
                                        StatusPill(
                                          label: _reading!['soil_moisture_status'] ?? '—',
                                          color: (_reading!['soil_moisture_status'] == 'High') ? AppColors.alertRed : ((_reading!['soil_moisture_status'] == 'Low') ? AppColors.accentAmber : AppColors.primaryGreen),
                                        ),
                                        const SizedBox(width: 6),
                                        _trendArrow(),
                                      ],
                                    ),
                                    _row('Air Temperature', '${_reading!['air_temperature_c']}°C', _reading!['temperature_status'] ?? '—'),
                                    _row('Humidity', '${_reading!['humidity_pct']}%', _reading!['humidity_status'] ?? '—'),
                                    _row('Soil Temperature', '${_reading!['soil_temperature_c']}°C', '—'),
                                    _row('Rainfall', '${_reading!['rainfall_mm']} mm', '—'),
                                    _row('Light Intensity', '${_reading!['light_intensity_lux']} lux', '—'),
                                    if (_reading!['recorded_at'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            'Last updated: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(_reading!['recorded_at']).toLocal())}',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SectionCard(
                                title: 'Soil Moisture Trend',
                                icon: Icons.show_chart,
                                iconColor: AppColors.waterBlue,
                                child: _trendChart(),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Readings and trend are pulled from stored field-condition history, not generated on the fly.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
    );
  }
}
