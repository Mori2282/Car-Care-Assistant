import 'dart:convert';

import 'package:car_care_app/core/catalog/catalog_api.dart';
import 'package:car_care_app/features/expenses/domain/models/expense_point.dart';
import 'package:car_care_app/features/expenses/presentation/widgets/expenses_chart.dart';
import 'package:car_care_app/features/maintenance/data/repositories/local_maintenance_repository.dart';
import 'package:car_care_app/features/maintenance/domain/models/maintenance_record.dart';
import 'package:car_care_app/features/maintenance/domain/models/maintenance_schedule.dart';
import 'package:car_care_app/features/parts/data/parts_repository.dart';
import 'package:car_care_app/features/parts/domain/part.dart';
import 'package:car_care_app/features/vehicle/data/repositories/local_vehicle_repository.dart';
import 'package:car_care_app/features/vehicle/domain/models/vehicle.dart';
import 'package:car_care_app/features/vehicle/domain/models/vin.dart';
import 'package:car_care_app/features/vehicle/domain/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const car = Vehicle(
    id: 'a',
    brand: 'Skoda',
    model: 'Octavia',
    mileage: 55000,
    vin: 'TMBJJ7NE1J0123456',
    year: 2018,
  );
  const part = Part(
    name: 'Фильтр',
    brand: 'MANN',
    number: 'HU-7008',
    oe: '04L115562',
    source: 'Ручная запись',
    fitmentConfirmed: false,
  );
  const schedule = MaintenanceSchedule(
    id: 's1',
    title: 'Фильтр',
    intervalMileage: 10000,
    description: '',
    lastCompletedMileage: 50000,
  );
  final record = MaintenanceRecord(
    id: 'r1',
    vehicleId: 'a',
    title: 'Замена',
    mileage: 58000,
    date: DateTime(2026, 11, 10),
    cost: 25,
    notes: '',
    type: 'filter',
  );

  test(
    'accepts international VIN format without a US checksum requirement',
    () {
      expect(isVin(normalizeVin(' tmbjj7ne1j0123456 ')), isTrue);
      expect(isVin('TMBJJ7NEIJ0123456'), isFalse);
      expect(isVin('AVX-20012'), isFalse);
    },
  );

  test(
    'preserves existing garage and rejects a duplicate VIN after normalization',
    () async {
      final old =
          car.toJson()
            ..remove('variant')
            ..remove('catalogId');
      SharedPreferences.setMockInitialValues({
        'vehicles_list_v1': jsonEncode([old]),
      });
      final repo = LocalVehicleRepository();
      expect((await repo.getVehicles()).single, car);
      await expectLater(
        repo.saveVehicle(car.copyWith(id: 'b', vin: car.vin.toLowerCase())),
        throwsA(isA<DuplicateVin>()),
      );
      await repo.saveVehicle(car.copyWith(mileage: 60000));
      await repo.select(car.id);
      expect(await LocalVehicleRepository().selectedId(), car.id);
      expect(
        (await LocalVehicleRepository().getVehicles()).single.mileage,
        60000,
      );
    },
  );

  test(
    'serializes saved parts across writes and keeps cars isolated',
    () async {
      final repo = PartsRepository(CatalogApi(baseUrl: ''));
      await Future.wait([
        repo.save('a', part),
        repo.save(
          'a',
          const Part(
            name: 'Другой фильтр',
            brand: 'Bosch',
            number: 'P9000',
            oe: '04L115562',
            source: 'Ручная запись',
            fitmentConfirmed: false,
          ),
        ),
        repo.save('b', part),
      ]);
      final reopened = PartsRepository(CatalogApi(baseUrl: ''));
      expect(await reopened.load('a'), hasLength(2));
      expect((await reopened.load('b')).single.key, part.key);
      await reopened.remove('a', part);
      expect(await reopened.load('a'), hasLength(1));
      expect(await reopened.load('b'), hasLength(1));
    },
  );

  test(
    'reads legacy journal and saves completion with the plan in one write',
    () async {
      SharedPreferences.setMockInitialValues({
        'maintenance_records_v1': jsonEncode([record]),
        'maintenance_schedules_a': jsonEncode([schedule]),
      });
      final repo = LocalMaintenanceRepository();
      expect((await repo.getMaintenance('a')).records.single.id, 'r1');
      expect((await repo.getMaintenance('a')).schedules, isEmpty);
      await repo.addSchedule('a', schedule);
      final id = (await repo.getMaintenance('a')).schedules.single.id;
      await repo.addRecord(record, scheduleId: id);
      final reopened = await LocalMaintenanceRepository().getMaintenance('a');
      expect(reopened.records, hasLength(2));
      expect(reopened.schedules.single.getRemainingMileage(59000), 9000);
      expect((await repo.getMaintenance('b')).records, isEmpty);
    },
  );

  test('expense summary respects both month and year', () {
    final expenses = [
      for (final (year, month, cost) in [
        (2026, 1, 10.0),
        (2025, 12, 20.0),
        (2025, 1, 50.0),
      ])
        ExpensePoint(
          id: '',
          date: DateTime(year, month, 5),
          amount: cost,
          category: '',
          vehicleId: 'a',
        ),
    ];
    final result = totalsByMonth(expenses, DateTime(2026, 1, 10));
    expect(result[DateTime(2026, 1)], 10);
    expect(result[DateTime(2025, 12)], 20);
    expect(result.values.reduce((a, b) => a + b), 30);
  });
}
