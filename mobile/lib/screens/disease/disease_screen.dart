import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/crop_service.dart';
import '../../services/misc_services.dart';
import '../../widgets/section_card.dart';

class DiseaseScreen extends StatefulWidget {
  const DiseaseScreen({super.key});
  @override
  State<DiseaseScreen> createState() => _DiseaseScreenState();
}

class _DiseaseScreenState extends State<DiseaseScreen> {
  final _cropService = CropService();
  final _diseaseService = DiseaseService();
  final _picker = ImagePicker();

  File? _image;
  Map<String, dynamic>? _result;
  bool _analyzing = false;
  String? _error;
  int? _activeCropId;

  @override
  void initState() {
    super.initState();
    _loadActiveCrop();
  }

  Future<void> _loadActiveCrop() async {
    try {
      final crops = await _cropService.myCrops();
      if (crops.isNotEmpty) {
        final active = crops.firstWhere((c) => c['is_active'] == 1, orElse: () => crops.first);
        setState(() => _activeCropId = active['id']);
      }
    } catch (_) {}
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      _image = File(picked.path);
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    if (_image == null || _activeCropId == null) return;
    setState(() {
      _analyzing = true;
      _error = null;
    });
    try {
      final result = await _diseaseService.predict(_activeCropId!, _image!);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Disease Detection')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeCropId == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Add and activate a crop first to use disease detection.', style: TextStyle(color: AppColors.textMuted)),
            ),
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _image == null
                ? const Center(child: Icon(Icons.image_outlined, size: 48, color: AppColors.textMuted))
                : ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(_image!, fit: BoxFit.cover)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _activeCropId == null ? null : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Capture'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _activeCropId == null ? null : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Upload'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_image == null || _analyzing) ? null : _analyze,
              child: _analyzing
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Analyze'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: AppColors.alertRed)),
            ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            SectionCard(
              title: _result!['disease_name'] ?? 'Unknown',
              icon: Icons.local_florist_outlined,
              iconColor: AppColors.alertRed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Confidence: ${_result!['confidence_pct']}%'),
                  const SizedBox(height: 8),
                  Text(_result!['description'] ?? ''),
                  const SizedBox(height: 8),
                  Text('Treatment: ${_result!['treatment'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_result!['is_demo_model'] == true) ...[
                    const SizedBox(height: 12),
                    Text(_result!['model_note'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
