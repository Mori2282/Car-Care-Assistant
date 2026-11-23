import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class MaintenanceSchedule extends Equatable {
  const MaintenanceSchedule({
    required this.id,
    required this.title,
    required this.intervalMileage,
    required this.description,
    required this.lastCompletedMileage,
    this.intervalDays = 0,
    this.lastCompletedOn,
  });

  final String id;
  final String title;
  final int intervalMileage;
  final String description;
  final int lastCompletedMileage;
  final int intervalDays;
  final DateTime? lastCompletedOn;

  int getRemainingMileage(int currentVehicleMileage) =>
      lastCompletedMileage + intervalMileage - currentVehicleMileage;

  DateTime? get dueDate {
    final last = lastCompletedOn;
    return last == null || intervalDays <= 0
        ? null
        : DateTime(last.year, last.month, last.day + intervalDays, 9);
  }

  bool isDue(int mileage, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final due = dueDate;
    return (intervalMileage > 0 && getRemainingMileage(mileage) <= 1000) ||
        (due != null &&
            !due.isAfter(
              DateTime(today.year, today.month, today.day + 7, 23, 59),
            ));
  }

  String dueSummary(int mileage) {
    final remaining = getRemainingMileage(mileage);
    final due = dueDate;
    return [
      if (intervalMileage > 0)
        remaining <= 0
            ? 'Пора по пробегу'
            : 'Через ${NumberFormat.decimalPattern('ru').format(remaining)} км',
      if (due != null) 'До ${DateFormat('d MMMM', 'ru').format(due)}',
    ].join(' · ');
  }

  MaintenanceSchedule copyWith({
    String? id,
    int? lastCompletedMileage,
    DateTime? lastCompletedOn,
  }) => MaintenanceSchedule(
    id: id ?? this.id,
    title: title,
    intervalMileage: intervalMileage,
    description: description,
    lastCompletedMileage: lastCompletedMileage ?? this.lastCompletedMileage,
    intervalDays: intervalDays,
    lastCompletedOn: lastCompletedOn ?? this.lastCompletedOn,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'intervalMileage': intervalMileage,
    'description': description,
    'lastCompletedMileage': lastCompletedMileage,
    'intervalDays': intervalDays,
    'lastCompletedOn': lastCompletedOn?.toIso8601String(),
  };

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) =>
      MaintenanceSchedule(
        id: json['id'] as String,
        title: json['title'] as String,
        intervalMileage: json['intervalMileage'] as int,
        description: json['description'] as String,
        lastCompletedMileage: json['lastCompletedMileage'] as int,
        intervalDays: json['intervalDays'] as int? ?? 0,
        lastCompletedOn:
            json['lastCompletedOn'] == null
                ? null
                : DateTime.parse(json['lastCompletedOn'] as String),
      );

  @override
  List<Object?> get props => [
    id,
    title,
    intervalMileage,
    description,
    lastCompletedMileage,
    intervalDays,
    lastCompletedOn,
  ];
}

MaintenanceSchedule? nearestMaintenance(
  List<MaintenanceSchedule> schedules,
  int mileage,
  DateTime now,
) {
  if (schedules.isEmpty) return null;
  double urgency(MaintenanceSchedule item) {
    final km =
        item.intervalMileage > 0
            ? item.getRemainingMileage(mileage) / 1000
            : double.infinity;
    final days =
        item.dueDate == null
            ? double.infinity
            : item.dueDate!.difference(now).inHours / 168;
    return km < days ? km : days;
  }

  return schedules.reduce((a, b) => urgency(a) <= urgency(b) ? a : b);
}
