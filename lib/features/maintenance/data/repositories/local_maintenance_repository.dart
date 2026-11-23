import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/serial_writes.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../../domain/repositories/maintenance_repository.dart';

class LocalMaintenanceRepository implements MaintenanceRepository {
  final _writes = SerialWrites();
  static String _key(String vehicleId) => 'maintenance_v2_$vehicleId';

  @override
  Future<MaintenanceData> getMaintenance(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(vehicleId));
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MaintenanceData(
        schedules: _parse(json['schedules'], MaintenanceSchedule.fromJson),
        records: _parse(json['records'], MaintenanceRecord.fromJson),
      );
    }
    final records = prefs.getString('maintenance_records_v1');
    final schedules = prefs.getString('maintenance_schedules_$vehicleId');
    final legacySchedules = _parse(
      schedules == null ? null : jsonDecode(schedules),
      MaintenanceSchedule.fromJson,
    );
    return MaintenanceData(
      // The previous version generated fixed s1–s5 schedules for every vehicle.
      schedules:
          legacySchedules
              .where((item) => !RegExp(r'^s[1-5]$').hasMatch(item.id))
              .toList(),
      records:
          _parse(
            records == null ? null : jsonDecode(records),
            MaintenanceRecord.fromJson,
          ).where((record) => record.vehicleId == vehicleId).toList(),
    );
  }

  static List<T> _parse<T>(
    Object? json,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      json == null
          ? []
          : (json as List).cast<Map<String, dynamic>>().map(fromJson).toList();

  @override
  Future<void> addRecord(MaintenanceRecord record, {String? scheduleId}) =>
      _writes.run(() async {
        final data = await getMaintenance(record.vehicleId);
        final records = [
          record.copyWith(id: const Uuid().v4()),
          ...data.records,
        ]..sort((a, b) => b.date.compareTo(a.date));
        final schedules =
            data.schedules.map((schedule) {
              if (schedule.id != scheduleId ||
                  schedule.lastCompletedMileage > record.mileage) {
                return schedule;
              }
              return schedule.copyWith(lastCompletedMileage: record.mileage);
            }).toList();
        await _write(
          record.vehicleId,
          MaintenanceData(records: records, schedules: schedules),
        );
      });

  @override
  Future<void> addSchedule(String vehicleId, MaintenanceSchedule schedule) =>
      _writes.run(() async {
        final data = await getMaintenance(vehicleId);
        await _write(
          vehicleId,
          MaintenanceData(
            records: data.records,
            schedules: [
              ...data.schedules,
              schedule.copyWith(id: const Uuid().v4()),
            ],
          ),
        );
      });

  Future<void> _write(String vehicleId, MaintenanceData data) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      _key(vehicleId),
      jsonEncode({'records': data.records, 'schedules': data.schedules}),
    )) {
      throw StateError('Maintenance storage write failed');
    }
  }
}
