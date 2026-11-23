import '../models/maintenance_schedule.dart';
import '../models/maintenance_record.dart';

abstract class MaintenanceRepository {
  Future<List<MaintenanceSchedule>> getMaintenanceSchedules(String vehicleId);
  Future<List<MaintenanceRecord>> getMaintenanceRecords(String vehicleId);
  Future<void> addMaintenanceRecord(MaintenanceRecord record);
  Future<void> completeMaintenanceSchedule(String scheduleId, int completionMileage);
}
