import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/repositories/maintenance_repository.dart';
import 'maintenance_state.dart';

class MaintenanceCubit extends Cubit<MaintenanceState> {
  final MaintenanceRepository _maintenanceRepository;

  MaintenanceCubit(this._maintenanceRepository) : super(MaintenanceInitial());

  Future<void> loadMaintenanceData(String vehicleId) async {
    emit(MaintenanceLoading());
    try {
      final schedules = await _maintenanceRepository.getMaintenanceSchedules(vehicleId);
      final records = await _maintenanceRepository.getMaintenanceRecords(vehicleId);
      emit(MaintenanceLoaded(schedules: schedules, records: records));
    } catch (e) {
      emit(MaintenanceError('Не удалось загрузить данные ТО: ${e.toString()}'));
    }
  }

  Future<void> addRecord({
    required String vehicleId,
    required String title,
    required int mileage,
    required double cost,
    required String notes,
    required String type,
    DateTime? date, // <-- 1. Принимаем выбранную дату
    String? associatedScheduleId,
  }) async {
    if (state is MaintenanceLoaded) {
      try {
        final newRecord = MaintenanceRecord(
          id: '', // Сгенерируется репозиторием
          vehicleId: vehicleId,
          title: title,
          mileage: mileage,
          date: date ?? DateTime.now(), // <-- 2. Используем выбранную дату (или текущую, если не задана)
          cost: cost,
          notes: notes,
          type: type,
        );

        await _maintenanceRepository.addMaintenanceRecord(newRecord);

        // Если запись закрывает какую-то плановую регламентную задачу
        if (associatedScheduleId != null) {
          await _maintenanceRepository.completeMaintenanceSchedule(associatedScheduleId, mileage);
        }

        // Перезагружаем данные
        final schedules = await _maintenanceRepository.getMaintenanceSchedules(vehicleId);
        final records = await _maintenanceRepository.getMaintenanceRecords(vehicleId);
        emit(MaintenanceLoaded(schedules: schedules, records: records));
      } catch (e) {
        emit(MaintenanceError('Не удалось добавить запись ТО: ${e.toString()}'));
      }
    }
  }
}