import 'dart:convert';

import '../../../../core/storage/garage_storage.dart';
import '../../../../core/storage/serial_writes.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vin.dart';
import '../../domain/repositories/vehicle_repository.dart';

class LocalVehicleRepository implements VehicleRepository {
  LocalVehicleRepository({
    GarageStorage storage = const PreferencesGarageStorage(),
  }) : _storage = storage;
  final GarageStorage _storage;
  final _writes = SerialWrites();
  static const _key = 'vehicles_list_v1';
  static const _selection = 'selected_vehicle_id';

  @override
  Future<List<Vehicle>> getVehicles() async {
    final json = await _storage.read(_key);
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .cast<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .toList();
  }

  @override
  Future<void> saveVehicle(Vehicle vehicle) => _writes.run(() async {
    final vehicles = await getVehicles();
    final vin = normalizeVin(vehicle.vin);
    if (vin.isNotEmpty &&
        vehicles.any(
          (item) => item.id != vehicle.id && normalizeVin(item.vin) == vin,
        )) {
      throw const DuplicateVin();
    }
    final index = vehicles.indexWhere((item) => item.id == vehicle.id);
    if (index < 0) {
      vehicles.add(vehicle);
    } else {
      vehicles[index] = vehicle;
    }
    await _storage.write(_key, jsonEncode(vehicles));
  });

  @override
  Future<String?> selectedId() async => _storage.read(_selection);

  @override
  Future<void> select(String id) => _writes.run(() async {
    await _storage.write(_selection, id);
  });
}
