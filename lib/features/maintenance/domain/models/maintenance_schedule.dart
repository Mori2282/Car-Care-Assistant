import 'package:equatable/equatable.dart';

class MaintenanceSchedule extends Equatable {
  final String id;
  final String title;
  final int intervalMileage;
  final String description;
  final int lastCompletedMileage;

  const MaintenanceSchedule({
    required this.id,
    required this.title,
    required this.intervalMileage,
    required this.description,
    required this.lastCompletedMileage,
  });

  int getRemainingMileage(int currentVehicleMileage) {
    final nextDue = lastCompletedMileage + intervalMileage;
    return nextDue - currentVehicleMileage;
  }

  bool isDue(int currentVehicleMileage) {
    return getRemainingMileage(currentVehicleMileage) <= 1000;
  }

  MaintenanceSchedule copyWith({
    String? id,
    String? title,
    int? intervalMileage,
    String? description,
    int? lastCompletedMileage,
  }) {
    return MaintenanceSchedule(
      id: id ?? this.id,
      title: title ?? this.title,
      intervalMileage: intervalMileage ?? this.intervalMileage,
      description: description ?? this.description,
      lastCompletedMileage: lastCompletedMileage ?? this.lastCompletedMileage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'intervalMileage': intervalMileage,
      'description': description,
      'lastCompletedMileage': lastCompletedMileage,
    };
  }

  factory MaintenanceSchedule.fromJson(Map<String, dynamic> json) {
    return MaintenanceSchedule(
      id: json['id'] as String,
      title: json['title'] as String,
      intervalMileage: json['intervalMileage'] as int,
      description: json['description'] as String,
      lastCompletedMileage: json['lastCompletedMileage'] as int,
    );
  }

  @override
  List<Object?> get props => [id, title, intervalMileage, description, lastCompletedMileage];
}
