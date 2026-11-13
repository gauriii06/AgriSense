import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';
import '../crops/crop_list_screen.dart';
import '../weather/weather_screen.dart';
import '../field/field_screen.dart';
import '../pest/pest_screen.dart';
import '../disease/disease_screen.dart';
import '../market/market_screen.dart';
import '../recommendations/recommendations_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DashboardService _dashboardService = DashboardService();
  Map<String, dynamic>? _summary;
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
      final data = await _dashboardService.summary();
      setState(() => _summary = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AgriSense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorRetryView(message: _error!, onRetry: _load)
                : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final data = _summary!;
    if (data['has_active_crop'] != true) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.grass, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(data['message'] ?? 'Add a crop to get started.', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CropListScreen())),
            child: const Text('Manage Crops'),
          ),
        ],
      );
    }

    final weather = data['weather'] ?? {};
    final field = data['field'] ?? {};
    final pest = data['pest_risk'] ?? {};
    final market = data['market'];
    final alert = data['priority_alert'];
    final recommendation = data['recommendation'];
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('$greeting, ${data['farmer_name'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
        Text('${data['farm_name'] ?? ''} · ${data['crop_name'] ?? ''}', style: const TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Weather',
          icon: Icons.wb_cloudy_outlined,
          iconColor: AppColors.waterBlue,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WeatherScreen())),
          child: Text(
            '${weather['temperature_c'] ?? '--'}°C · ${weather['humidity_pct'] ?? '--'}% humidity\n'
            '${weather['forecast_summary'] ?? weather['condition'] ?? ''}',
          ),
        ),
        SectionCard(
          title: 'Field',
          icon: Icons.grass,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FieldScreen())),
          child: Text('Soil moisture: ${field['soil_moisture_pct'] != null ? '${field['soil_moisture_pct']}%' : 'No reading yet'}'),
        ),
        SectionCard(
          title: 'Pest Risk',
          icon: Icons.bug_report_outlined,
          iconColor: AppColors.riskColor(pest['level'] ?? 'low'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PestScreen())),
          child: Row(
            children: [
              StatusPill(label: (pest['level'] ?? 'low').toString().toUpperCase(), color: AppColors.riskColor(pest['level'] ?? 'low')),
              const SizedBox(width: 8),
              Text('${pest['probability_pct'] ?? 0}%'),
            ],
          ),
        ),
        SectionCard(
          title: 'Market',
          icon: Icons.storefront_outlined,
          iconColor: AppColors.accentAmber,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MarketScreen())),
          child: Text(market != null ? '₹${market['price']}/quintal · ${market['market']}' : 'No market data yet'),
        ),
        if (alert != null)
          SectionCard(
            title: 'Priority Alert',
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.alertRed,
            child: Text('${alert['message']}\n${alert['recommended_action'] ?? ''}'),
          ),
        if (recommendation != null)
          SectionCard(
            title: 'Recommendation',
            icon: Icons.lightbulb_outline,
            iconColor: AppColors.primaryGreen,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecommendationsScreen())),
            child: Text('${recommendation['title']}\n${recommendation['action']}'),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiseaseScreen())),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Check Disease'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CropListScreen())),
                icon: const Icon(Icons.eco_outlined),
                label: const Text('My Crops'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const Text('Log Out'),
          ),
        ),
      ],
    );
  }
}
