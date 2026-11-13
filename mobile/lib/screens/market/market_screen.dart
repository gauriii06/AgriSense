import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _cropService = CropService();
  final _marketService = MarketService();
  Map<String, dynamic>? _market;
  int? _cropId;
  bool _loading = true;
  String? _error;
  String? _emptyMessage;
  final _targetController = TextEditingController();

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
        setState(() => _emptyMessage = 'Add a crop first to see market prices.');
        return;
      }
      final active = crops.firstWhere((c) => c['is_active'] == 1, orElse: () => crops.first);
      _cropId = active['crop_id'];
      final market = await _marketService.prices(_cropId!);
      setState(() => _market = market);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _setTarget() async {
    final value = double.tryParse(_targetController.text);
    if (value == null || _cropId == null) return;
    await _marketService.setTargetPrice(_cropId!, value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Target price set — you will be alerted when reached.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : _emptyMessage != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_emptyMessage!)))
                  : _market == null
                      ? const Center(child: Text('No market data available for this crop yet.'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              SectionCard(
                                title: 'Nearby Markets',
                                icon: Icons.storefront_outlined,
                                iconColor: AppColors.accentAmber,
                                child: Column(
                                  children: (_market!['markets'] as List).map((m) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text(m['market_name'])),
                                          Text('₹${m['price_per_quintal']}/quintal'),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              SectionCard(
                                title: 'Best Available',
                                icon: Icons.star_border,
                                iconColor: AppColors.primaryGreen,
                                child: Text('${_market!['best_market']} · ₹${_market!['best_price']}/quintal\nTrend: ${_market!['trend']}'),
                              ),
                              SectionCard(
                                title: 'Set Target Price',
                                icon: Icons.flag_outlined,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _targetController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: '₹ per quintal'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(onPressed: _setTarget, child: const Text('Set')),
                                  ],
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Demo market data for this environment. Swap in a live Agmarknet feed later without changing the app.',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
    );
  }
}
