import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as time_data;
import 'package:timezone/timezone.dart' as tz;
import '../storage/serial_writes.dart';

import '../../features/maintenance/domain/repositories/maintenance_repository.dart';
import '../../features/vehicle/domain/repositories/vehicle_repository.dart';

class MaintenanceReminders {
  MaintenanceReminders(this.vehicles, this.maintenance);
  final VehicleRepository vehicles;
  final MaintenanceRepository maintenance;
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;
  final _updates = SerialWrites();
  static const _prefix = 'car-care-maintenance:';
  static const _enabledKey = 'maintenance_notification_enabled';

  Future<void> _initialize() async {
    time_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('car_care_mark'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<bool> enable() async {
    await (_ready ??= _initialize());
    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final allowed =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true, badge: false) ??
        false;
    if (allowed) {
      await (await SharedPreferences.getInstance()).setBool(_enabledKey, true);
    }
    return allowed;
  }

  Future<void> disable() async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, false);
    await refresh();
  }

  Future<void> refresh() => _updates.run(() async {
    final enabled = await isEnabled();
    if (!enabled && _ready == null) return;
    final tasks = <({String key, String title, String car, DateTime date})>[];
    if (enabled) {
      final now = DateTime.now();
      for (final car in await vehicles.getVehicles()) {
        final data = await maintenance.getMaintenance(car.id);
        for (final item in data.schedules) {
          final date = item.dueDate;
          if (date == null || !date.isAfter(now)) continue;
          tasks.add((
            key: '$_prefix${car.id}:${item.id}',
            title: item.title,
            car: '${car.brand} ${car.model}',
            date: date,
          ));
        }
      }
      tasks.sort((a, b) => a.date.compareTo(b.date));
    }
    await (_ready ??= _initialize());
    for (final entry in await _plugin.pendingNotificationRequests()) {
      if (entry.payload?.startsWith(_prefix) ?? false) {
        await _plugin.cancel(entry.id);
      }
    }
    var id = 32000;
    for (final task in tasks.take(60)) {
      await _plugin.zonedSchedule(
        id++,
        'Пора на обслуживание',
        '${task.car} · ${task.title}',
        tz.TZDateTime.from(task.date.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'maintenance_due',
            'Напоминания о ТО',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.key,
      );
    }
  });

  Future<void> refreshQuietly() async {
    try {
      await refresh();
    } catch (_) {
      // The calendar inside the garage still works without OS notifications.
    }
  }
}
