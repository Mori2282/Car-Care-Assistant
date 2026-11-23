import 'dart:convert';

import '../../features/expenses/domain/models/expense_point.dart';
import '../../features/maintenance/domain/models/maintenance_record.dart';
import '../../features/maintenance/domain/models/maintenance_schedule.dart';
import '../../features/parts/domain/part.dart';
import '../../features/vehicle/domain/models/vehicle.dart';
import 'garage_storage.dart';

const maxGarageBackupBytes = 8 * 1024 * 1024;

String encodeGarageBackup(Map<String, String> documents) => jsonEncode({
  'format': 'car-care-garage',
  'version': 1,
  'documents': documents,
});

Map<String, String> decodeGarageBackup(String contents) {
  final value = jsonDecode(contents);
  if (value is! Map<String, dynamic> ||
      value['format'] != 'car-care-garage' ||
      value['version'] != 1 ||
      value['documents'] is! Map<String, dynamic>) {
    throw const FormatException('Unknown backup format');
  }
  final documents = <String, String>{};
  for (final entry in (value['documents'] as Map<String, dynamic>).entries) {
    final key = entry.key;
    final raw = entry.value;
    if (!isGarageKey(key) || raw is! String) {
      throw const FormatException('Invalid document');
    }
    if (key != 'selected_vehicle_id') {
      final document = jsonDecode(raw);
      if (key == 'vehicles_list_v1') {
        _validateList(document, Vehicle.fromJson);
      } else if (key.startsWith('maintenance_v2_')) {
        _validateList(document['records'], MaintenanceRecord.fromJson);
        _validateList(document['schedules'], MaintenanceSchedule.fromJson);
      } else if (key == 'maintenance_records_v1') {
        _validateList(document, MaintenanceRecord.fromJson);
      } else if (key.startsWith('maintenance_schedules_')) {
        _validateList(document, MaintenanceSchedule.fromJson);
      } else if (key.startsWith('custom_expenses_v1_')) {
        _validateList(document, ExpensePoint.fromJson);
      } else if (key.startsWith('saved_parts_v1_')) {
        _validateList(document, Part.fromJson);
        // An imported file cannot prove that a provider confirmed compatibility.
        documents[key] = jsonEncode([
          for (final part in document as List)
            {
              ...part as Map<String, dynamic>,
              'fitmentConfirmed': false,
              'fitmentVehicleId': '',
            },
        ]);
        continue;
      }
    }
    documents[key] = raw;
  }
  final vehicles = jsonDecode(documents['vehicles_list_v1'] ?? '[]') as List;
  final ids = vehicles.map((item) => (item as Map)['id'] as String).toSet();
  if (ids.length != vehicles.length || ids.contains('')) {
    throw const FormatException('Invalid vehicle identifiers');
  }
  return documents;
}

void _validateList(Object? items, Object Function(Map<String, dynamic>) parse) {
  if (items is! List) throw const FormatException('Invalid data list');
  for (final item in items) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Invalid entry');
    }
    parse(item);
  }
}
