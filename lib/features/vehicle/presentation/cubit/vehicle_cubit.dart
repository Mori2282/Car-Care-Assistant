import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';
import 'vehicle_state.dart';

class VehicleCubit extends Cubit<VehicleState> {
  final VehicleRepository _vehicleRepository;

  VehicleCubit(this._vehicleRepository) : super(VehicleInitial());

  Future<void> loadVehicles() async {
    emit(VehicleLoading());
    try {
      final vehicles = await _vehicleRepository.getVehicles();
      if (vehicles.isEmpty) {
        emit(const VehicleLoaded(vehicles: [], selectedVehicle: null));
      } else {
        emit(VehicleLoaded(vehicles: vehicles, selectedVehicle: vehicles.first));
      }
    } catch (e) {
      emit(VehicleError('Не удалось загрузить список автомобилей: ${e.toString()}'));
    }
  }

  void selectVehicle(Vehicle vehicle) {
    if (state is VehicleLoaded) {
      final loadedState = state as VehicleLoaded;
      emit(loadedState.copyWith(selectedVehicle: vehicle));
    }
  }

  Future<void> addVehicle({
    required String brand,
    required String model,
    required int mileage,
    required String vin,
    required int year,
  }) async {
    try {
      final currentLoaded = state as VehicleLoaded?;
      final previousVehicles = currentLoaded?.vehicles ?? [];
      final previousSelected = currentLoaded?.selectedVehicle;

      emit(VehicleLoading());

      final newVehicle = Vehicle(
        id: '', // Будет сгенерировано в репозитории
        brand: brand,
        model: model,
        mileage: mileage,
        vin: vin,
        year: year,
      );

      await _vehicleRepository.addVehicle(newVehicle);
      
      // Перезагружаем список
      final vehicles = await _vehicleRepository.getVehicles();
      // Выбираем свежесозданный автомобиль (он последний в списке)
      final addedVehicle = vehicles.lastWhere((v) => v.vin == vin, orElse: () => vehicles.last);
      emit(VehicleLoaded(vehicles: vehicles, selectedVehicle: addedVehicle));
    } catch (e) {
      emit(VehicleError('Не удалось добавить автомобиль: ${e.toString()}'));
    }
  }
}
