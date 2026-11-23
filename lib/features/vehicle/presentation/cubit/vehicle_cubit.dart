import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  VehicleCubit(this._repository) : super(VehicleInitial());

  final VehicleRepository _repository;

  Future<void> loadVehicles({bool fromBackup = false}) async {
    final previous = state;
    if (fromBackup || previous is! VehicleLoaded) emit(VehicleLoading());
    try {
      final vehicles = await _repository.getVehicles();
      final selectedId =
          !fromBackup && previous is VehicleLoaded
              ? previous.selectedVehicle?.id
              : await _repository.selectedId();
      final selected =
          vehicles.where((v) => v.id == selectedId).firstOrNull ??
          vehicles.firstOrNull;
      if (!isClosed) {
        emit(VehicleLoaded(vehicles: vehicles, selectedVehicle: selected));
      }
    } catch (_) {
      if (!isClosed) emit(const VehicleError('Не удалось загрузить гараж'));
    }
  }

  Future<void> selectVehicle(Vehicle vehicle) async {
    final previous = state;
    if (previous is! VehicleLoaded) return;
    emit(previous.copyWith(selectedVehicle: vehicle));
    try {
      await _repository.select(vehicle.id);
    } catch (_) {
      // The current selection remains usable even if preferences cannot be saved.
    }
  }

  Future<void> saveVehicle(Vehicle vehicle) async {
    final item =
        vehicle.id.isEmpty ? vehicle.copyWith(id: const Uuid().v4()) : vehicle;
    await _repository.saveVehicle(item);
    final vehicles = await _repository.getVehicles();
    if (isClosed) return;
    emit(VehicleLoaded(vehicles: vehicles, selectedVehicle: item));
    await selectVehicle(item);
  }
}
