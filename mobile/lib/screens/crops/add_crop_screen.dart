import 'package:flutter/material.dart';
import '../../widgets/section_card.dart';
import '../../services/crop_service.dart';

class AddCropScreen extends StatefulWidget {
  const AddCropScreen({super.key});
  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _cropService = CropService();
  final _formKey = GlobalKey<FormState>();

  List<dynamic> _farms = [];
  List<dynamic> _catalog = [];
  int? _selectedFarmId;
  String? _selectedCropName;
  final _varietyController = TextEditingController();
  final _farmSizeController = TextEditingController();
  DateTime? _sowingDate;
  String _growthStage = 'sowing';

  // New-farm fields (shown if the farmer has no farms yet)
  final _newFarmNameController = TextEditingController();
  final _newFarmSizeController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  static const _growthStages = ['sowing', 'germination', 'vegetative', 'flowering', 'fruiting', 'maturity', 'harvested'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final farms = await _cropService.myFarms();
      final catalog = await _cropService.cropCatalog();
      setState(() {
        _farms = farms;
        _catalog = catalog;
        if (farms.isNotEmpty) _selectedFarmId = farms.first['id'];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      int farmId;
      if (_selectedFarmId != null) {
        farmId = _selectedFarmId!;
      } else {
        farmId = await _cropService.createFarm(
          farmName: _newFarmNameController.text.trim(),
          farmSizeAcres: double.tryParse(_newFarmSizeController.text),
        );
      }

      await _cropService.addCrop(
        farmId: farmId,
        cropName: _selectedCropName!,
        variety: _varietyController.text.trim(),
        sowingDate: _sowingDate?.toIso8601String().split('T').first,
        farmSizeAcres: double.tryParse(_farmSizeController.text),
        growthStage: _growthStage,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Crop')),
      body: _loading
          ? const LoadingView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_farms.isNotEmpty) ...[
                      SectionCard(
                        title: 'Farm',
                        icon: Icons.landscape_outlined,
                        child: DropdownButtonFormField<int>(
                          value: _selectedFarmId,
                          items: _farms.map<DropdownMenuItem<int>>((f) => DropdownMenuItem(value: f['id'], child: Text(f['farm_name']))).toList(),
                          onChanged: (v) => setState(() => _selectedFarmId = v),
                        ),
                      ),
                    ] else ...[
                      SectionCard(
                        title: 'New Farm',
                        icon: Icons.landscape_outlined,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _newFarmNameController,
                              decoration: const InputDecoration(labelText: 'Farm name'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _newFarmSizeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Farm size (acres)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SectionCard(
                      title: 'Crop Details',
                      icon: Icons.eco_outlined,
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: _selectedCropName,
                            decoration: const InputDecoration(labelText: 'Crop'),
                            items: _catalog.map<DropdownMenuItem<String>>((c) => DropdownMenuItem(value: c['name'] as String, child: Text(c['name']))).toList(),
                            onChanged: (v) => setState(() => _selectedCropName = v),
                            validator: (v) => v == null ? 'Select a crop' : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(controller: _varietyController, decoration: const InputDecoration(labelText: 'Variety (optional)')),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _farmSizeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Area planted (acres)'),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: _growthStage,
                            decoration: const InputDecoration(labelText: 'Growth stage'),
                            items: _growthStages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _growthStage = v ?? 'sowing'),
                          ),
                          const SizedBox(height: 10),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_sowingDate == null ? 'Select sowing date' : 'Sown: ${_sowingDate!.toLocal()}'.split(' ').first),
                            trailing: const Icon(Icons.calendar_today_outlined),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) setState(() => _sowingDate = picked);
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Add Crop'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
