import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../../domain/repositories/maintenance_repository.dart';
import 'maintenance_state.dart';

class MaintenanceCubit extends Cubit<MaintenanceState> {
  MaintenanceCubit(this._repository, this.vehicleId)
    : super(MaintenanceInitial());

  final MaintenanceRepository _repository;
  final String vehicleId;

  Future<void> load() async {
    if (state is! MaintenanceLoaded) emit(MaintenanceLoading());
    try {
      final data = await _repository.getMaintenance(vehicleId);
      if (!isClosed) {
        emit(
          MaintenanceLoaded(schedules: data.schedules, records: data.records),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(const MaintenanceError('Не удалось загрузить обслуживание'));
      }
    }
  }

  Future<void> addRecord(MaintenanceRecord record, {String? scheduleId}) async {
    await _repository.addRecord(record, scheduleId: scheduleId);
    if (!isClosed) await load();
  }

  Future<void> addSchedule(MaintenanceSchedule schedule) async {
    await _repository.addSchedule(vehicleId, schedule);
    if (!isClosed) await load();
  }
}
