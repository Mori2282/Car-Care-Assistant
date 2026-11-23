import 'package:dio/dio.dart';

import '../../../../core/catalog/catalog_api.dart';
import '../../domain/models/vin.dart';

class VehicleMatch {
  const VehicleMatch({
    required this.brand,
    required this.model,
    required this.source,
    this.year,
    this.variant = '',
    this.catalogId = '',
    this.note = '',
  });

  final String brand;
  final String model;
  final int? year;
  final String variant;
  final String catalogId;
  final String source;
  final String note;
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

  bool get hasCatalog => _catalog.isConfigured;

  Future<List<VehicleMatch>> find(
    String identifier, {
    String market = '',
    int? modelYear,
  }) async {
    final value = normalizeVin(identifier);
    final frame = isFrame(value);
    final yearHint = _year(modelYear);
    if (!frame && !isVin(value)) return [];
    Object? catalogError;
    if (hasCatalog) {
      try {
        final rows = await _catalog.query(frame ? 'frame' : 'vin', {
          frame ? 'frame' : 'vin': value,
          if (market.isNotEmpty || frame)
            'market': market.isEmpty ? 'JP' : market,
          if (yearHint != null) 'modelYear': yearHint.toString(),
        });
        final matches = _catalogMatches(rows, value, frame: frame);
        if (matches.isNotEmpty) return matches;
      } catch (error) {
        catalogError = error;
      }
    }
    if (frame) {
      if (catalogError != null) throw catalogError;
      return [];
    }

    Map<String, dynamic>? row;
    Object? publicError;
    try {
      row = await _publicLookup('DecodeVinValues/$value', {
        if (yearHint != null) 'modelyear': yearHint,
      });
    } catch (error) {
      publicError = error;
    }
    if (row != null) {
      final brand = _text(row['Make']);
      final model = _text(row['Model']);
      final codes =
          _text(row['ErrorCode']).split(',').map((code) => code.trim()).toSet();
      final unreliableModel = codes.any(
        {'5', '6', '7', '8', '11', '14', '400'}.contains,
      );
      final clean =
          codes.contains('0') && !codes.contains('1') && !unreliableModel;
      if (clean && brand.isNotEmpty && model.isNotEmpty) {
        return [
          VehicleMatch(
            brand: brand,
            model: model,
            year: _year(row['ModelYear']),
            source: 'NHTSA vPIC',
            note: 'Базовые данные. Комплектация не проверена.',
          ),
        ];
      }
      if (brand.isNotEmpty) {
        return [
          VehicleMatch(
            brand: brand,
            model: unreliableModel ? '' : model,
            year: clean ? _year(row['ModelYear']) : null,
            source: 'NHTSA vPIC',
            note: 'Неполное совпадение. Проверьте данные по документам.',
          ),
        ];
      }
    }
    Map<String, dynamic>? wmi;
    try {
      wmi = await _publicLookup('DecodeWMI/${manufacturerId(value)!}', {});
    } catch (_) {
      if (publicError != null) throw publicError;
      rethrow;
    }
    final makes =
        _text(wmi?['Make'])
            .split(RegExp(r'[,;|/]'))
            .map(_text)
            .where((make) => make.isNotEmpty)
            .toSet();
    final manufacturer = _text(wmi?['ManufacturerName']);
    if (makes.isNotEmpty || manufacturer.isNotEmpty) {
      final note = [
        if (manufacturer.isNotEmpty) 'Производитель: $manufacturer.',
        if (makes.length > 1)
          'Код используется несколькими марками. Выберите свою по документам.',
        'Модель и год укажите вручную.',
      ].join(' ');
      return [
        for (final make in (makes.isEmpty ? [''] : makes))
          VehicleMatch(
            brand: make,
            model: '',
            source: 'Код производителя · NHTSA vPIC',
            note: note,
          ),
      ];
    }
    if (publicError != null) throw publicError;
    if (catalogError != null) throw catalogError;
    return [];
  }

  Future<Map<String, dynamic>?> _publicLookup(
    String endpoint,
    Map<String, Object> parameters,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'https://vpic.nhtsa.dot.gov/api/vehicles/$endpoint',
      queryParameters: {'format': 'json', ...parameters},
    );
    final rows = response.data?['Results'];
    if (rows is! List) throw const FormatException('Invalid VIN response');
    return rows.whereType<Map<String, dynamic>>().firstOrNull;
  }

  List<VehicleMatch> _catalogMatches(
    List<Map<String, dynamic>> rows,
    String identifier, {
    required bool frame,
  }) {
    final matches = <String, VehicleMatch>{};
    for (final row in rows) {
      final brand = _text(row['brand']);
      final model = _text(row['model']);
      final variant = _text(row['variant']);
      final echoed = _text(row['matchedIdentifier']);
      if (brand.isEmpty && model.isEmpty) continue;
      if (echoed.isNotEmpty && normalizeVin(echoed) != identifier) continue;
      final source = _text(row['source']);
      final year = _year(row['year']);
      final verification = _text(row['verification']);
      final id = _text(row['id']);
      final exact =
          id.isNotEmpty &&
          brand.isNotEmpty &&
          model.isNotEmpty &&
          variant.isNotEmpty &&
          (verification == 'exact' && echoed.isNotEmpty ||
              (!frame && verification.isEmpty));
      final match = VehicleMatch(
        brand: brand,
        model: model,
        year: year,
        variant: variant,
        source: source.isEmpty ? 'Каталог' : source,
        catalogId: exact ? id : '',
        note:
            exact
                ? 'Сверьте модификацию с документами.'
                : 'Подсказка каталога. Комплектация не подтверждена.',
      );
      matches.putIfAbsent(
        '$brand|$model|$year|$variant|${match.catalogId}',
        () => match,
      );
    }
    return matches.values.take(30).toList();
  }

  static String _text(Object? value) {
    if (value is! String) return '';
    final text = value.trim();
    return const {
          'NOT APPLICABLE',
          'NOT AVAILABLE',
          'UNKNOWN',
          'N/A',
          'NULL',
        }.contains(text.toUpperCase())
        ? ''
        : text;
  }

  static int? _year(Object? value) {
    final year = int.tryParse(value.toString());
    return year != null && year >= 1886 && year <= DateTime.now().year + 1
        ? year
        : null;
  }
}
