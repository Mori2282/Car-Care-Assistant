import 'dart:convert';

import 'package:car_care_app/core/storage/garage_backup.dart';
import 'package:car_care_app/features/expenses/domain/models/expense_point.dart';
import 'package:car_care_app/features/expenses/presentation/widgets/expenses_chart.dart';
import 'package:car_care_app/features/maintenance/domain/models/maintenance_schedule.dart';
import 'package:car_care_app/features/parts/domain/part.dart';
import 'package:car_care_app/features/parts/domain/parts_sources.dart';
import 'package:car_care_app/features/vehicle/domain/models/vehicle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_care_app/features/maintenance/data/repositories/local_maintenance_repository.dart';
import 'package:car_care_app/features/maintenance/domain/models/maintenance_record.dart';

Vehicle car(String brand, String model, int year, {String market = ''}) =>
    Vehicle(
      id: 'car-a',
      brand: brand,
      model: model,
      year: year,
      mileage: 200000,
      vin: 'WDB2110061A000000',
      market: market,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'manual routes match the car and never add its VIN to external links',
    () {
      final chevy = partsSources(
        car('Chevrolet', 'Equinox', 2025, market: 'US'),
        'фильтр',
      );
      final mercedes = partsSources(
        car('Mercedes-Benz', 'E-Class W211', 2004, market: 'EU'),
        'A000123',
      );
      final byd = partsSources(
        car('BYD', 'Song Plus', 2025, market: 'CN'),
        'фильтр',
      );
      expect(chevy.first.uri.host, 'parts.chevrolet.com');
      expect(mercedes.first.uri.path, '/en/catalog/cars/mercedes/');
      expect(byd.first.uri.host, 'www.tecalliance.cn');
      for (final source in [...chevy, ...mercedes, ...byd]) {
        expect(source.uri.toString(), isNot(contains('WDB2110061A000000')));
      }
    },
  );

  test('a date-only service can outrank distant work by mileage', () {
    final last = DateTime(2026, 11, 18);
    final date = MaintenanceSchedule(
      id: 'date',
      title: 'Дата',
      description: '',
      intervalMileage: 0,
      lastCompletedMileage: 80000,
      intervalDays: 10,
      lastCompletedOn: last,
    );
    const mileage = MaintenanceSchedule(
      id: 'km',
      title: 'Пробег',
      description: '',
      intervalMileage: 10000,
      lastCompletedMileage: 80000,
    );
    expect(date.dueDate, DateTime(2026, 11, 28, 9));
    expect(
      nearestMaintenance([mileage, date], 81000, DateTime(2026, 11, 23)),
      date,
    );
    expect(date.isDue(81000, now: DateTime(2026, 11, 23)), isTrue);
  });

  test(
    'backup preserves vehicle records and rejects unknown or malformed documents',
    () {
      final vehicle = car('Mercedes-Benz', 'E-Class', 2003);
      final documents = {
        'vehicles_list_v1': jsonEncode([vehicle]),
      };
      expect(decodeGarageBackup(encodeGarageBackup(documents)), documents);
      expect(
        () => decodeGarageBackup(encodeGarageBackup({'unknown': '[]'})),
        throwsFormatException,
      );
      expect(
        () =>
            decodeGarageBackup(encodeGarageBackup({'vehicles_list_v1': '{}'})),
        throwsFormatException,
      );
    },
  );

  test(
    'a backed up part must be reconfirmed and evidence is scoped to one variant',
    () {
      const part = Part(
        name: 'Фильтр',
        brand: 'Brand',
        number: 'A12',
        oe: 'X1',
        source: 'Каталог',
        fitmentConfirmed: true,
        fitmentVehicleId: 'provider:a',
      );
      expect(part.fitsCatalogVehicle('provider:a'), isTrue);
      expect(part.fitsCatalogVehicle('provider:b'), isFalse);
      final documents = decodeGarageBackup(
        encodeGarageBackup({
          'saved_parts_v1_car-a': jsonEncode([part]),
        }),
      );
      final restored = Part.fromJson(
        (jsonDecode(documents['saved_parts_v1_car-a']!) as List).single,
      );
      expect(restored.number, 'A12');
      expect(restored.fitsCatalogVehicle('provider:a'), isFalse);
    },
  );

  test('legacy amounts stay in RUB and summaries keep currencies separate', () {
    final rub = ExpensePoint.fromJson({
      'id': 'r',
      'date': '2026-11-10',
      'amount': 300,
      'category': 'ТО',
      'vehicleId': 'car-a',
    });
    final byn = rub.copyWith(id: 'b', currency: 'BYN', amount: 50);
    final now = DateTime(2026, 11, 23);
    expect(totalsByMonth([rub, byn], now).values.first, 300);
    expect(totalsByMonth([rub, byn], now, currency: 'BYN').values.first, 50);
  });
  test(
    'saving a completed service advances the date without duplicating the plan',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalMaintenanceRepository();
      final planned = MaintenanceSchedule(
        id: '',
        title: 'Масло',
        description: '',
        intervalMileage: 10000,
        intervalDays: 365,
        lastCompletedMileage: 100000,
        lastCompletedOn: DateTime(2025, 11, 18),
      );
      await repo.addSchedule('car-a', planned);
      final plan = (await repo.getMaintenance('car-a')).schedules.single;
      await repo.addRecord(
        MaintenanceRecord(
          id: '',
          vehicleId: 'car-a',
          title: 'Масло',
          mileage: 110000,
          date: DateTime(2026, 11, 18),
          cost: 50,
          currency: 'BYN',
          notes: '',
          type: 'other',
        ),
        scheduleId: plan.id,
      );
      final completed = await repo.getMaintenance('car-a');
      expect(completed.schedules.single.id, plan.id);
      expect(completed.schedules.single.dueDate, DateTime(2027, 11, 18, 9));
      final record = completed.records.single;
      await repo.addRecord(record.copyWith(cost: 55), replaceExisting: true);
      expect((await repo.getMaintenance('car-a')).records.single.cost, 55);
      await repo.removeRecord('car-a', record.id);
      expect((await repo.getMaintenance('car-a')).records, isEmpty);
      expect(
        (await repo.getMaintenance('car-a')).schedules.single.dueDate,
        DateTime(2027, 11, 18, 9),
      );
    },
  );
}
