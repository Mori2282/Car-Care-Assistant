import '../models/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles();
  Future<void> addVehicle(Vehicle vehicle);
}
