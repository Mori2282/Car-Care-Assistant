import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/repositories/vehicle_repository.dart';

class MockVehicleRepository implements VehicleRepository {
  static const _key = 'vehicles_list_v1';

  final List<Vehicle> _defaultVehicles = [
    const Vehicle(
      id: '1',
      brand: 'BMW',
      model: '3 Series (320i)',
      mileage: 82450,
      vin: 'WBA5F7C56LF123456',
      year: 2020,
    ),
    const Vehicle(
      id: '2',
      brand: 'Tesla',
      model: 'Model Y Long Range',
      mileage: 24300,
      vin: '5YJ3E1EB8LF654321',
      year: 2022,
    ),
  ];

  @override
  Future<List<Vehicle>> getVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null) {
      await _saveToPrefs(prefs, _defaultVehicles);
      return _defaultVehicles;
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((item) => Vehicle.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> addVehicle(Vehicle vehicle) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getVehicles();
    final newVehicle = vehicle.id.isEmpty
        ? vehicle.copyWith(id: const Uuid().v4())
        : vehicle;
    list.add(newVehicle);
    await _saveToPrefs(prefs, list);
  }

  Future<void> _saveToPrefs(SharedPreferences prefs, List<Vehicle> list) async {
    final jsonStr = jsonEncode(list.map((v) => v.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
}
