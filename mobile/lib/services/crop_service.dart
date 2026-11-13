import '../services/api_service.dart';

class CropService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> cropCatalog() async {
    final res = await _api.get('/crops/catalog');
    return res['data'];
  }

  Future<List<dynamic>> myCrops() async {
    final res = await _api.get('/crops');
    return res['data'];
  }

  Future<List<dynamic>> myFarms() async {
    final res = await _api.get('/farms');
    return res['data'];
  }

  Future<int> createFarm({required String farmName, double? farmSizeAcres, String? locationText}) async {
    final res = await _api.post('/farms', {
      'farm_name': farmName,
      'farm_size_acres': farmSizeAcres,
      'location_text': locationText,
    });
    return res['farm_id'];
  }

  Future<int> addCrop({
    required int farmId,
    required String cropName,
    String? variety,
    String? sowingDate,
    double? farmSizeAcres,
    String growthStage = 'sowing',
  }) async {
    final res = await _api.post('/crops', {
      'farm_id': farmId,
      'crop_name': cropName,
      'variety': variety,
      'sowing_date': sowingDate,
      'farm_size_acres': farmSizeAcres,
      'growth_stage': growthStage,
    });
    return res['farmer_crop_id'];
  }

  Future<void> setActiveCrop(int farmerCropId) async {
    await _api.post('/crops/$farmerCropId/activate', {});
  }

  Future<void> updateCrop(int farmerCropId, Map<String, dynamic> fields) async {
    await _api.put('/crops/$farmerCropId', fields);
  }
}
