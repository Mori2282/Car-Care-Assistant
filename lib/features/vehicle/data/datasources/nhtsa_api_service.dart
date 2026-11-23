import 'package:dio/dio.dart';

class NhtsaApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://vpic.nhtsa.dot.gov/api',
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// Отправляет реальный REST API запрос к государственной базе NHTSA (США)
  Future<Map<String, dynamic>?> decodeVin(String vin) async {
    try {
      final response = await _dio.get('/vehicles/decodevin/$vin?format=json');
      
      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['Results'] as List<dynamic>;

        String getValue(String variableName) {
          final item = results.firstWhere(
            (element) => element['Variable'] == variableName,
            orElse: () => {'Value': null},
          );
          return item['Value']?.toString().trim() ?? '';
        }

        final make = getValue('Make');
        final model = getValue('Model');
        final year = getValue('Model Year');

        if (make.isNotEmpty || model.isNotEmpty) {
          return {
            'brand': make.isNotEmpty ? make : 'Иномарка',
            'model': model.isNotEmpty ? model : 'Стандарт',
            'year': int.tryParse(year) ?? DateTime.now().year,
          };
        }
      }
      return null;
    } catch (e) {
      print('Ошибка при обращении к NHTSA REST API: $e');
      return null;
    }
  }
}