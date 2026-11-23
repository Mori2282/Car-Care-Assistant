import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/storage/serial_writes.dart';
import '../../../core/catalog/catalog_api.dart';
import '../../vehicle/domain/models/vehicle.dart';
import '../domain/part.dart';

class PartsRepository {
  final _writes = SerialWrites();
  PartsRepository(this._catalog);
  final CatalogApi _catalog;

  bool get hasCatalog => _catalog.isConfigured;

  Future<List<Part>> search(Vehicle vehicle, String query) async {
    final rows = await _catalog.query('parts', {
      'query': query,
      'vehicleId': vehicle.catalogId,
      'brand': vehicle.brand,
      'model': vehicle.model,
      'year': vehicle.year.toString(),
      'variant': vehicle.variant,
    });
    final parts = <String, Part>{};
    for (final row in rows) {
      final result = Part.fromJson(row);
      if (result.number.isEmpty || result.oe.isEmpty || result.brand.isEmpty) {
        continue;
      }
      final part = Part(
        name: result.name,
        brand: result.brand,
        number: result.number,
        oe: result.oe,
        source: result.source.isEmpty ? 'Каталог' : result.source,
        fitmentConfirmed:
            vehicle.catalogId.isNotEmpty &&
            row['vehicleId'] == vehicle.catalogId &&
            result.fitmentConfirmed,
      );
      final previous = parts[part.key];
      if (previous == null || part.fitmentConfirmed) parts[part.key] = part;
    }
    return parts.values.toList()..sort(
      (a, b) =>
          (b.fitmentConfirmed ? 1 : 0).compareTo(a.fitmentConfirmed ? 1 : 0),
    );
  }

  Future<List<Part>> load(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(vehicleId));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(Part.fromJson)
        .toList();
  }

  Future<List<Part>> save(String vehicleId, Part part) => _writes.run(() async {
    final parts = await load(vehicleId);
    final index = parts.indexWhere((item) => item.key == part.key);
    if (index < 0) {
      parts.insert(0, part);
    } else {
      parts[index] = part;
    }
    await _write(vehicleId, parts);
    return parts;
  });

  Future<List<Part>> remove(String vehicleId, Part part) =>
      _writes.run(() async {
        final parts = await load(vehicleId);
        parts.removeWhere((item) => item.key == part.key);
        await _write(vehicleId, parts);
        return parts;
      });

  String _key(String id) => 'saved_parts_v1_$id';

  Future<void> _write(String vehicleId, List<Part> parts) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_key(vehicleId), jsonEncode(parts))) {
      throw StateError('Parts storage write failed');
    }
  }
}
