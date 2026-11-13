import 'dart:io';
import '../services/api_service.dart';

class MarketService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> prices(int cropId) async {
    final res = await _api.get('/market/prices', query: {'crop_id': cropId});
    return res['data'];
  }

  Future<void> setTargetPrice(int cropId, double targetPrice) async {
    await _api.post('/market/target-price', {'crop_id': cropId, 'target_price': targetPrice});
  }
}

class PestService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> risk(int farmerCropId) async {
    final res = await _api.get('/pests/risk', query: {'farmer_crop_id': farmerCropId});
    return res['data'];
  }
}

class DiseaseService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> predict(int farmerCropId, File imageFile) async {
    final res = await _api.uploadImage(
      '/disease/predict',
      {'farmer_crop_id': '$farmerCropId'},
      imageFile,
    );
    return res['data'];
  }
}

class RecommendationService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> get(int farmerCropId) async {
    final res = await _api.get('/recommendations', query: {'farmer_crop_id': farmerCropId});
    return res['data'];
  }
}

class DashboardService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> summary() async {
    final res = await _api.get('/dashboard/summary');
    return res['data'];
  }
}

class NotificationService {
  final ApiService _api = ApiService();

  Future<List<dynamic>> generateAlerts({int? farmerCropId}) async {
    final res = await _api.get('/alerts/generate', query: farmerCropId != null ? {'farmer_crop_id': farmerCropId} : null);
    return res['data'];
  }

  Future<List<dynamic>> list() async {
    final res = await _api.get('/alerts/notifications');
    return res['data'];
  }

  Future<List<dynamic>> activeAlerts() async {
    final res = await _api.get('/alerts/active');
    return res['data'];
  }

  Future<void> markRead(int notificationId) async {
    await _api.put('/alerts/notifications/$notificationId/read', {});
  }

  /// Dismisses the underlying alert (not just the notification wrapper).
  /// The alert leaves the active list but stays in history.
  Future<void> dismissAlert(int alertId) async {
    await _api.put('/alerts/$alertId/dismiss', {});
  }
}
