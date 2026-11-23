import 'dart:convert';

import '../../../../core/storage/garage_storage.dart';
import '../../../../core/storage/serial_writes.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../../domain/repositories/maintenance_repository.dart';

class LocalMaintenanceRepository implements MaintenanceRepository {
  LocalMaintenanceRepository({
    GarageStorage storage = const PreferencesGarageStorage(),
  }) : _storage = storage;
  final GarageStorage _storage;
  final _writes = SerialWrites();
  static String _key(String vehicleId) => 'maintenance_v2_$vehicleId';

  @override
  Future<MaintenanceData> getMaintenance(String vehicleId) async {
    final raw = await _storage.read(_key(vehicleId));
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return MaintenanceData(
        schedules: _parse(json['schedules'], MaintenanceSchedule.fromJson),
        records: _parse(json['records'], MaintenanceRecord.fromJson),
      );
    }
    final records = await _storage.read('maintenance_records_v1');
    final schedules = await _storage.read('maintenance_schedules_$vehicleId');
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
  Future<void> addRecord(
    MaintenanceRecord record, {
    String? scheduleId,
    bool replaceExisting = false,
  }) => _writes.run(() async {
    final data = await getMaintenance(record.vehicleId);
    final records = [
      !replaceExisting || record.id.isEmpty
          ? record.copyWith(id: const Uuid().v4())
          : record,
      ...data.records.where((item) => !replaceExisting || item.id != record.id),
    ]..sort((a, b) => b.date.compareTo(a.date));
    final schedules =
        data.schedules.map((schedule) {
          if (schedule.id != scheduleId ||
              schedule.lastCompletedMileage > record.mileage) {
            return schedule;
          }
          return schedule.copyWith(
            lastCompletedMileage: record.mileage,
            lastCompletedOn:
                schedule.lastCompletedOn == null ||
                        !record.date.isBefore(schedule.lastCompletedOn!)
                    ? record.date
                    : null,
          );
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
              ...data.schedules.where((item) => item.id != schedule.id),
              schedule.id.isEmpty
                  ? schedule.copyWith(id: const Uuid().v4())
                  : schedule,
            ],
          ),
        );
      });

  @override
  Future<void> removeRecord(String vehicleId, String id) =>
      _writes.run(() async {
        final data = await getMaintenance(vehicleId);
        await _write(
          vehicleId,
          MaintenanceData(
            schedules: data.schedules,
            records: data.records.where((record) => record.id != id).toList(),
          ),
        );
      });

  @override
  Future<void> removeSchedule(String vehicleId, String id) =>
      _writes.run(() async {
        final data = await getMaintenance(vehicleId);
        await _write(
          vehicleId,
          MaintenanceData(
            schedules:
                data.schedules.where((schedule) => schedule.id != id).toList(),
            records: data.records,
          ),
        );
      });
  Future<void> _write(String vehicleId, MaintenanceData data) async {
    await _storage.write(
      _key(vehicleId),
      jsonEncode({'records': data.records, 'schedules': data.schedules}),
    );
  }
}
