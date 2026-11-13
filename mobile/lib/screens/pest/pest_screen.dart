import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';

class PestScreen extends StatefulWidget {
  const PestScreen({super.key});
  @override
  State<PestScreen> createState() => _PestScreenState();
}

class _PestScreenState extends State<PestScreen> {
  final _cropService = CropService();
  final _pestService = PestService();
  Map<String, dynamic>? _risk;
  bool _loading = true;
  String? _error;
  String? _emptyMessage;

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
        setState(() => _emptyMessage = 'Add a crop first to see pest risk.');
        return;
      }
      final active = crops.firstWhere((c) => c['is_active'] == 1, orElse: () => crops.first);
      final risk = await _pestService.risk(active['id']);
      setState(() => _risk = risk);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pest Risk')),
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
                        children: [
                          SectionCard(
                            title: _risk!['pest_name'] ?? 'No pest currently flagged',
                            icon: Icons.bug_report_outlined,
                            iconColor: AppColors.riskColor(_risk!['risk_level'] ?? 'low'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('${_risk!['probability_pct']}%', style: Theme.of(context).textTheme.headlineSmall),
                                    const SizedBox(width: 10),
                                    StatusPill(
                                      label: (_risk!['risk_level'] ?? 'low').toString().toUpperCase(),
                                      color: AppColors.riskColor(_risk!['risk_level'] ?? 'low'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SectionCard(
                            title: 'Why?',
                            icon: Icons.info_outline,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: (_risk!['contributing_factors'] as List)
                                  .map((f) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text('•  $f'),
                                      ))
                                  .toList(),
                            ),
                          ),
                          SectionCard(
                            title: 'Recommended Action',
                            icon: Icons.checklist_outlined,
                            iconColor: AppColors.primaryGreen,
                            child: Text(_risk!['preventive_action'] ?? ''),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
