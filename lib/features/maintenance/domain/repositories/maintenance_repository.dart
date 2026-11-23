import '../models/maintenance_schedule.dart';
import '../models/maintenance_record.dart';

class MaintenanceData {
  const MaintenanceData({required this.records, required this.schedules});
  final List<MaintenanceRecord> records;
  final List<MaintenanceSchedule> schedules;
}

abstract class MaintenanceRepository {
  Future<MaintenanceData> getMaintenance(String vehicleId);
  Future<void> addRecord(MaintenanceRecord record, {String? scheduleId});
  Future<void> addSchedule(String vehicleId, MaintenanceSchedule schedule);
}
