import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../../domain/repositories/maintenance_repository.dart';
import 'maintenance_state.dart';

class MaintenanceCubit extends Cubit<MaintenanceState> {
  MaintenanceCubit(this._repository, this.vehicleId, {this.onChanged})
    : super(MaintenanceInitial());

  final MaintenanceRepository _repository;
  final String vehicleId;
  final Future<void> Function()? onChanged;

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

  Future<void> addRecord(
    MaintenanceRecord record, {
    String? scheduleId,
    bool replaceExisting = false,
  }) async {
    await _repository.addRecord(
      record,
      scheduleId: scheduleId,
      replaceExisting: replaceExisting,
    );
    if (!isClosed) await load();
    await onChanged?.call();
  }

  Future<void> addSchedule(MaintenanceSchedule schedule) async {
    await _repository.addSchedule(vehicleId, schedule);
    if (!isClosed) await load();
    await onChanged?.call();
  }

  Future<void> removeRecord(String id) async {
    await _repository.removeRecord(vehicleId, id);
    if (!isClosed) await load();
    await onChanged?.call();
  }

  Future<void> removeSchedule(String id) async {
    await _repository.removeSchedule(vehicleId, id);
    if (!isClosed) await load();
    await onChanged?.call();
  }
}
