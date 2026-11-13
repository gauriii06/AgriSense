import '../services/api_service.dart';

class WeatherService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> current() async {
    final res = await _api.get('/weather/current');
    return res['data'];
  }

  Future<List<dynamic>> forecast() async {
    final res = await _api.get('/weather/forecast');
    return res['data'];
  }
}

class FieldService {
  final ApiService _api = ApiService();

  Future<Map<String, dynamic>?> latestReading(int farmerCropId) async {
    final res = await _api.get('/field/readings', query: {'farmer_crop_id': farmerCropId});
    return res['data'];
  }

  Future<List<dynamic>> history(int farmerCropId) async {
    final res = await _api.get('/field/history', query: {'farmer_crop_id': farmerCropId});
    return res['data'];
  }

  Future<void> addReading(int farmerCropId, Map<String, dynamic> reading) async {
    await _api.post('/field/readings', {'farmer_crop_id': farmerCropId, ...reading});
  }
}
