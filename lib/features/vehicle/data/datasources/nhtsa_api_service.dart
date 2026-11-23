import 'package:dio/dio.dart';

import '../../../../core/catalog/catalog_api.dart';

class VehicleMatch {
  const VehicleMatch({
    required this.brand,
    required this.model,
    required this.source,
    this.year,
    this.variant = '',
    this.catalogId = '',
  });

  final String brand;
  final String model;
  final int? year;
  final String variant;
  final String catalogId;
  final String source;
}

class VinLookup {
  VinLookup(this._catalog, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
            ),
          );

  final CatalogApi _catalog;
  final Dio _dio;

  Future<List<VehicleMatch>> find(
    String vin, {
    String market = '',
    int? modelYear,
  }) async {
    var catalogFailed = false;
    if (_catalog.isConfigured) {
      try {
        final rows = await _catalog.query('vin', {
          'vin': vin,
          if (market.isNotEmpty) 'market': market,
          if (modelYear != null) 'modelYear': modelYear.toString(),
        });
        final matches =
            rows
                .map(
                  (row) => VehicleMatch(
                    brand: _value(row['brand']),
                    model: _value(row['model']),
                    year: _year(row['year']),
                    variant: _value(row['variant']),
                    catalogId: _value(row['id']),
                    source:
                        _value(row['source']).isEmpty
                            ? 'Каталог'
                            : _value(row['source']),
                  ),
                )
                .where(
                  (match) => match.brand.isNotEmpty || match.model.isNotEmpty,
                )
                .toList();
        if (matches.isNotEmpty) return matches;
      } catch (_) {
        catalogFailed = true;
      }
    }
    final response = await _dio.get<Map<String, dynamic>>(
      'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/$vin',
      queryParameters: {
        'format': 'json',
        if (modelYear != null) 'modelyear': modelYear,
      },
    );
    final rows = response.data?['Results'];
    if (rows is! List) throw const FormatException('Invalid VIN response');
    final row = rows.whereType<Map<String, dynamic>>().firstOrNull;
    if (row != null) {
      final brand = _value(row['Make']);
      final model = _value(row['Model']);
      if (brand.isNotEmpty || model.isNotEmpty) {
        return [
          VehicleMatch(
            brand: brand,
            model: model,
            year: _year(row['ModelYear']),
            source: 'NHTSA vPIC',
          ),
        ];
      }
    }
    if (catalogFailed) throw StateError('Catalog is unavailable');
    return [];
  }

  static String _value(Object? value) => value is String ? value.trim() : '';

  static int? _year(Object? value) {
    final year = int.tryParse(value.toString());
    return year != null && year >= 1886 && year <= DateTime.now().year + 1
        ? year
        : null;
  }
}
