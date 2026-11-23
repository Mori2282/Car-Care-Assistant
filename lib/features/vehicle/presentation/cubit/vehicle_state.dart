import 'package:equatable/equatable.dart';
import '../../domain/models/vehicle.dart';

abstract class VehicleState extends Equatable {
  const VehicleState();

  @override
  List<Object?> get props => [];
}

class VehicleInitial extends VehicleState {}

class VehicleLoading extends VehicleState {}

class VehicleLoaded extends VehicleState {
  final List<Vehicle> vehicles;
  final Vehicle? selectedVehicle;

  const VehicleLoaded({required this.vehicles, this.selectedVehicle});

  VehicleLoaded copyWith({List<Vehicle>? vehicles, Vehicle? selectedVehicle}) {
    return VehicleLoaded(
      vehicles: vehicles ?? this.vehicles,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
    );
  }

  @override
  List<Object?> get props => [vehicles, selectedVehicle];
}

class VehicleError extends VehicleState {
  final String message;

  const VehicleError(this.message);

  @override
  List<Object?> get props => [message];
}
