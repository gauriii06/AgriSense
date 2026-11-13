import 'package:flutter/material.dart';
import '../services/crop_service.dart';

class CropProvider extends ChangeNotifier {
  final CropService _cropService = CropService();
  List<dynamic> crops = [];
  bool isLoading = false;

  Map<String, dynamic>? get activeCrop {
    try {
      return crops.firstWhere((c) => c['is_active'] == 1 || c['is_active'] == true);
    } catch (_) {
      return crops.isNotEmpty ? crops.first : null;
    }
  }

  Future<void> loadCrops() async {
    isLoading = true;
    notifyListeners();
    try {
      crops = await _cropService.myCrops();
    } catch (_) {
      crops = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setActive(int farmerCropId) async {
    await _cropService.setActiveCrop(farmerCropId);
    await loadCrops();
  }
}
