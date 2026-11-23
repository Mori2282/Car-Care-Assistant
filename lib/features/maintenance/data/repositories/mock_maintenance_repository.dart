import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/repositories/maintenance_repository.dart';

class MockMaintenanceRepository implements MaintenanceRepository {
  static const _schedulesKey = 'maintenance_schedules';
  static const _recordsKey = 'maintenance_records_v1';

  final List<MaintenanceSchedule> _defaultSchedules = [
    const MaintenanceSchedule(
      id: 's1',
      title: 'Замена моторного масла и фильтра',
      intervalMileage: 10000,
      description: 'Используйте сертифицированное масло 5W-30. Рекомендуется менять каждые 10 000 км или раз в год.',
      lastCompletedMileage: 80000,
    ),
    const MaintenanceSchedule(
      id: 's2',
      title: 'Замена воздушного фильтра',
      intervalMileage: 20000,
      description: 'Замена фильтра двигателя для оптимального впуска.',
      lastCompletedMileage: 70000,
    ),
    const MaintenanceSchedule(
      id: 's3',
      title: 'Замена салонного фильтра',
      intervalMileage: 15000,
      description: 'Обеспечивает чистый воздух в салоне и предотвращает запотевание стекол.',
      lastCompletedMileage: 82000,
    ),
    const MaintenanceSchedule(
      id: 's4',
      title: 'Проверка тормозной системы',
      intervalMileage: 30000,
      description: 'Осмотр тормозных дисков, колодок и замена тормозной жидкости при необходимости.',
      lastCompletedMileage: 60000,
    ),
    const MaintenanceSchedule(
      id: 's5',
      title: 'Замена свечей зажигания',
      intervalMileage: 60000,
      description: 'Регламентная замена иридиевых свечей зажигания.',
      lastCompletedMileage: 55000,
    ),
  ];

  final List<MaintenanceRecord> _defaultRecords = [
    MaintenanceRecord(
      id: 'r1',
      vehicleId: '1',
      title: 'Замена моторного масла (Liqui Moly 5W-30)',
      mileage: 80000,
      date: DateTime.now().subtract(const Duration(days: 45)),
      cost: 6500,
      notes: 'Залито масло Liqui Moly Top Tec 4200, заменен масляный фильтр MANN.',
      type: 'oil',
    ),
    MaintenanceRecord(
      id: 'r2',
      vehicleId: '1',
      title: 'Замена салонного фильтра (угольный)',
      mileage: 82000,
      date: DateTime.now().subtract(const Duration(days: 10)),
      cost: 1800,
      notes: 'Установлен угольный фильтр Filtron.',
      type: 'filter',
    ),
    MaintenanceRecord(
      id: 'r3',
      vehicleId: '1',
      title: 'Замена передних тормозных колодок',
      mileage: 75000,
      date: DateTime.now().subtract(const Duration(days: 120)),
      cost: 8500,
      notes: 'Колодки Brembo, смазка направляющих суппортов.',
      type: 'brake',
    ),
    MaintenanceRecord(
      id: 'r4',
      vehicleId: '1',
      title: 'Замена воздушного фильтра двигателя',
      mileage: 70000,
      date: DateTime.now().subtract(const Duration(days: 180)),
      cost: 1500,
      notes: 'Оригинальный фильтр BMW.',
      type: 'filter',
    ),
    MaintenanceRecord(
      id: 'r5',
      vehicleId: '1',
      title: 'Диагностика подвески',
      mileage: 65000,
      date: DateTime.now().subtract(const Duration(days: 240)),
      cost: 2000,
      notes: 'Люфтов не обнаружено, состояние сайлентблоков отличное.',
      type: 'suspension',
    ),
  ];

  @override
  Future<List<MaintenanceSchedule>> getMaintenanceSchedules(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('${_schedulesKey}_$vehicleId');
    if (jsonStr == null) {
      await _saveSchedules(prefs, vehicleId, _defaultSchedules);
      return _defaultSchedules;
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((item) => MaintenanceSchedule.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<MaintenanceRecord>> getMaintenanceRecords(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordsKey);
    if (jsonStr == null) {
      await _saveAllRecords(prefs, _defaultRecords);
      return _defaultRecords.where((r) => r.vehicleId == vehicleId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    final allRecords = decoded.map((item) => MaintenanceRecord.fromJson(item as Map<String, dynamic>)).toList();
    return allRecords.where((r) => r.vehicleId == vehicleId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addMaintenanceRecord(MaintenanceRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_recordsKey);
    List<MaintenanceRecord> allRecords = [];
    if (jsonStr != null) {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      allRecords = decoded.map((item) => MaintenanceRecord.fromJson(item as Map<String, dynamic>)).toList();
    } else {
      allRecords = List.from(_defaultRecords);
    }

    final newRecord = record.id.isEmpty
        ? record.copyWith(id: const Uuid().v4())
        : record;
    allRecords.add(newRecord);
    await _saveAllRecords(prefs, allRecords);
  }

  @override
  Future<void> completeMaintenanceSchedule(String scheduleId, int completionMileage) async {
  }

  Future<void> _saveSchedules(SharedPreferences prefs, String vehicleId, List<MaintenanceSchedule> list) async {
    final jsonStr = jsonEncode(list.map((s) => s.toJson()).toList());
    await prefs.setString('${_schedulesKey}_$vehicleId', jsonStr);
  }

  Future<void> _saveAllRecords(SharedPreferences prefs, List<MaintenanceRecord> list) async {
    final jsonStr = jsonEncode(list.map((r) => r.toJson()).toList());
    await prefs.setString(_recordsKey, jsonStr);
  }
}
