import 'package:dio/dio.dart';

class CatalogApi {
  CatalogApi({String? baseUrl, Dio? dio})
    : _base = Uri.tryParse(
        baseUrl ?? const String.fromEnvironment('CATALOG_API_URL'),
      ),
      _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              followRedirects: false,
            ),
          );

  final Uri? _base;
  final Dio _dio;

  bool get isConfigured =>
      _base?.scheme == 'https' &&
      _base!.host.isNotEmpty &&
      _base.userInfo.isEmpty &&
      !_base.hasQuery &&
      !_base.hasFragment;

  Future<List<Map<String, dynamic>>> query(
    String endpoint,
    Map<String, String> parameters,
  ) async {
    if (!isConfigured) return [];
    final base = _base!;
    final uri = base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        endpoint,
      ],
    );
    // In particular, VIN should stay out of URLs and ordinary access logs.
    final response = await _dio.postUri<Object?>(uri, data: parameters);
    final body = response.data;
    if (body is! Map || body['results'] is! List) {
      throw const FormatException('Invalid catalog response');
    }
    return (body['results'] as List).whereType<Map<String, dynamic>>().toList();
  }
}
