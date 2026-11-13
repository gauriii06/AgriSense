import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';

class RecommendationsScreen extends StatefulWidget {
  const RecommendationsScreen({super.key});
  @override
  State<RecommendationsScreen> createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  final _cropService = CropService();
  final _recService = RecommendationService();
  List<dynamic> _recs = [];
  bool _loading = true;
  String? _error;
  String? _emptyMessage;

  static const _categoryIcons = {
    'irrigation': Icons.water_drop_outlined,
    'pest_management': Icons.bug_report_outlined,
    'disease_management': Icons.local_florist_outlined,
    'crop_protection': Icons.shield_outlined,
    'harvesting': Icons.agriculture_outlined,
    'market_selection': Icons.storefront_outlined,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _emptyMessage = null;
    });
    try {
      final crops = await _cropService.myCrops();
      if (crops.isEmpty) {
        setState(() => _emptyMessage = 'Add a crop first to see recommendations.');
        return;
      }
      final active = crops.firstWhere((c) => c['is_active'] == 1, orElse: () => crops.first);
      final recs = await _recService.get(active['id']);
      setState(() => _recs = recs);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recommendations')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : _emptyMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_emptyMessage!)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _recs.map((r) {
                          final priority = r['priority'] ?? 'medium';
                          return SectionCard(
                            title: r['title'] ?? '',
                            icon: _categoryIcons[r['category']] ?? Icons.lightbulb_outline,
                            iconColor: priority == 'high' ? AppColors.alertRed : (priority == 'medium' ? AppColors.accentAmber : AppColors.primaryGreen),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r['explanation'] ?? '', style: const TextStyle(color: AppColors.textMuted)),
                                const SizedBox(height: 8),
                                Text(r['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}
