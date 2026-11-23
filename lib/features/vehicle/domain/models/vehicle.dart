import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  final String id;
  final String brand;
  final String model;
  final int mileage;
  final String vin;
  final int year;
  final String variant;
  final String catalogId;
  final String market;

  const Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.mileage,
    required this.vin,
    required this.year,
    this.variant = '',
    this.catalogId = '',
    this.market = '',
  });

  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? mileage,
    String? vin,
    int? year,
    String? variant,
    String? catalogId,
    String? market,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      mileage: mileage ?? this.mileage,
      vin: vin ?? this.vin,
      year: year ?? this.year,
      variant: variant ?? this.variant,
      catalogId: catalogId ?? this.catalogId,
      market: market ?? this.market,
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
      'variant': variant,
      'catalogId': catalogId,
      'market': market,
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
      variant: json['variant'] as String? ?? '',
      catalogId: json['catalogId'] as String? ?? '',
      market: json['market'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [
    id,
    brand,
    model,
    mileage,
    vin,
    year,
    variant,
    catalogId,
    market,
  ];
}
