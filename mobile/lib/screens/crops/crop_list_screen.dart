import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../widgets/section_card.dart';
import 'add_crop_screen.dart';

class CropListScreen extends StatefulWidget {
  const CropListScreen({super.key});
  @override
  State<CropListScreen> createState() => _CropListScreenState();
}

class _CropListScreenState extends State<CropListScreen> {
  final _cropService = CropService();
  List<dynamic> _crops = [];
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
      final crops = await _cropService.myCrops();
      setState(() => _crops = crops);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate(int farmerCropId) async {
    await _cropService.setActiveCrop(farmerCropId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Crops')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AddCropScreen()));
          if (added == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Crop'),
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorRetryView(message: _error!, onRetry: _load)
              : _crops.isEmpty
                  ? const Center(child: Text('No crops added yet. Tap "Add Crop" to get started.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: _crops.map((c) {
                          final isActive = c['is_active'] == 1 || c['is_active'] == true;
                          return SectionCard(
                            title: c['crop_name'] ?? '',
                            icon: Icons.eco_outlined,
                            iconColor: isActive ? AppColors.primaryGreen : AppColors.textMuted,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Variety: ${c['variety'] ?? '—'}'),
                                Text('Growth stage: ${c['growth_stage'] ?? '—'}'),
                                Text('Sown: ${c['sowing_date'] ?? '—'}'),
                                const SizedBox(height: 8),
                                if (isActive)
                                  const StatusPill(label: 'ACTIVE', color: AppColors.primaryGreen)
                                else
                                  OutlinedButton(
                                    onPressed: () => _activate(c['id']),
                                    child: const Text('Set as Active Crop'),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
    );
  }
}
