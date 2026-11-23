import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/serial_writes.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/vin.dart';
import '../../domain/repositories/vehicle_repository.dart';

class LocalVehicleRepository implements VehicleRepository {
  final _writes = SerialWrites();
  static const _key = 'vehicles_list_v1';
  static const _selection = 'selected_vehicle_id';

  @override
  Future<List<Vehicle>> getVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .cast<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .toList();
  }

  @override
  Future<void> saveVehicle(Vehicle vehicle) => _writes.run(() async {
    final prefs = await SharedPreferences.getInstance();
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
    if (!await prefs.setString(_key, jsonEncode(vehicles))) {
      throw StateError('Vehicle storage write failed');
    }
  });

  @override
  Future<String?> selectedId() async =>
      (await SharedPreferences.getInstance()).getString(_selection);

  @override
  Future<void> select(String id) => _writes.run(() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_selection, id)) {
      throw StateError('Selection storage write failed');
    }
  });
}
