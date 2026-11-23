import 'package:equatable/equatable.dart';

class MaintenanceRecord extends Equatable {
  final String id;
  final String vehicleId;
  final String title;
  final int mileage;
  final DateTime date;
  final double cost;
  final String notes;
  final String type;

  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.title,
    required this.mileage,
    required this.date,
    required this.cost,
    required this.notes,
    required this.type,
  });

  MaintenanceRecord copyWith({
    String? id,
    String? vehicleId,
    String? title,
    int? mileage,
    DateTime? date,
    double? cost,
    String? notes,
    String? type,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      title: title ?? this.title,
      mileage: mileage ?? this.mileage,
      date: date ?? this.date,
      cost: cost ?? this.cost,
      notes: notes ?? this.notes,
      type: type ?? this.type,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'title': title,
      'mileage': mileage,
      'date': date.toIso8601String(),
      'cost': cost,
      'notes': notes,
      'type': type,
    };
  }

  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      title: json['title'] as String,
      mileage: json['mileage'] as int,
      date: DateTime.parse(json['date'] as String),
      cost: (json['cost'] as num).toDouble(),
      notes: json['notes'] as String,
      type: json['type'] as String,
    );
  }

  @override
  List<Object?> get props => [
    id,
    vehicleId,
    title,
    mileage,
    date,
    cost,
    notes,
    type,
  ];
}
