import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  final String id;
  final String brand;
  final String model;
  final int mileage;
  final String vin;
  final int year;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.mileage,
    required this.vin,
    required this.year,
  });

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? mileage,
    String? vin,
    int? year,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      mileage: mileage ?? this.mileage,
      vin: vin ?? this.vin,
      year: year ?? this.year,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'mileage': mileage,
      'vin': vin,
      'year': year,
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      mileage: json['mileage'] as int,
      vin: json['vin'] as String,
      year: json['year'] as int,
    );
  }

  @override
  List<Object?> get props => [id, brand, model, mileage, vin, year];
}
