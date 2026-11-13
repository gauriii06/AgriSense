import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/weather_service.dart' as ws;
import '../../widgets/section_card.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _weatherService = ws.WeatherService();
  Map<String, dynamic>? _current;
  List<dynamic> _forecast = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final current = await _weatherService.current();
      final forecast = await _weatherService.forecast();
      setState(() {
        _current = current;
        _forecast = forecast;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_current?['fetched_at'] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Last updated: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(_current!['fetched_at']).toLocal())}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                      SectionCard(
                        title: 'Current Conditions',
                        icon: Icons.wb_cloudy_outlined,
                        iconColor: AppColors.waterBlue,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_current?['temperature_c'] ?? '--'}°C  (feels like ${_current?['feels_like_c'] ?? '--'}°C)',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('${_current?['weather_condition'] ?? ''}'),
                            const SizedBox(height: 8),
                            Text('Humidity: ${_current?['humidity_pct'] ?? '--'}%'),
                            Text('Wind: ${_current?['wind_speed_kmh'] ?? '--'} km/h'),
                            Text('Rainfall: ${_current?['rainfall_mm'] ?? '--'} mm'),
                            if (_current?['rain_probability_pct'] != null)
                              Text('Rain probability: ${_current?['rain_probability_pct']}%'),
                          ],
                        ),
                      ),
                      if ((_current?['significant_conditions'] as List?)?.isNotEmpty == true)
                        SectionCard(
                          title: 'Notable Conditions',
                          icon: Icons.warning_amber_rounded,
                          iconColor: AppColors.alertRed,
                          child: Text((_current?['significant_conditions'] as List).join(', ')),
                        ),
                      SectionCard(
                        title: 'Forecast',
                        icon: Icons.calendar_today_outlined,
                        child: Column(
                          children: _forecast.map((f) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(child: Text('${f['day']}')),
                                  Expanded(child: Text('${f['condition']}')),
                                  Text('${f['temp_high_c']}° / ${f['temp_low_c']}°'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
