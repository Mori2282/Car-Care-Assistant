import '../models/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles();
  Future<void> saveVehicle(Vehicle vehicle);
  Future<String?> selectedId();
  Future<void> select(String id);
}

class DuplicateVin implements Exception {
  const DuplicateVin();
}
