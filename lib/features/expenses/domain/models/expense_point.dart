import 'package:equatable/equatable.dart';

class ExpensePoint extends Equatable {
  final String id;
  final DateTime date;
  final double amount;
  final String category;
  final String vehicleId;

  const ExpensePoint({
    required this.id,
    required this.date,
    required this.amount,
    required this.category,
    required this.vehicleId,
  });

  ExpensePoint copyWith({
    String? id,
    DateTime? date,
    double? amount,
    String? category,
    String? vehicleId,
  }) {
    return ExpensePoint(
      id: id ?? this.id,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      vehicleId: vehicleId ?? this.vehicleId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'category': category,
      'vehicleId': vehicleId,
    };
  }

  factory ExpensePoint.fromJson(Map<String, dynamic> json) {
    return ExpensePoint(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num).toDouble(),
      category: json['category'] as String,
      vehicleId: json['vehicleId'] as String? ?? '1',
    );
  }

  @override
  List<Object?> get props => [id, date, amount, category, vehicleId];
}
