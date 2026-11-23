import 'dart:convert';

import '../../../../core/storage/garage_storage.dart';
import '../../../../core/storage/serial_writes.dart';
import 'package:uuid/uuid.dart';
import '../../../maintenance/domain/repositories/maintenance_repository.dart';
import '../../domain/models/expense_point.dart';
import '../../domain/repositories/expenses_repository.dart';

class LocalExpensesRepository implements ExpensesRepository {
  final _writes = SerialWrites();
  LocalExpensesRepository(
    this._maintenance, {
    GarageStorage storage = const PreferencesGarageStorage(),
  }) : _storage = storage;
  final GarageStorage _storage;
  final MaintenanceRepository _maintenance;

  String _key(String id) => 'custom_expenses_v1_$id';

  Future<List<ExpensePoint>> _loadCustom(String id) async {
    final raw = await _storage.read(_key(id));
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .cast<Map<String, dynamic>>()
        .map(ExpensePoint.fromJson)
        .toList();
  }

  @override
  Future<List<ExpensePoint>> getExpenses(String vehicleId) async {
    final custom = await _loadCustom(vehicleId);
    final data = await _maintenance.getMaintenance(vehicleId);
    return [
      ...custom,
      for (final record in data.records)
        if (record.cost > 0)
          ExpensePoint(
            id: 'maint_${record.id}',
            date: record.date,
            amount: record.cost,
            currency: record.currency,
            category: record.title,
            vehicleId: vehicleId,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addExpense(ExpensePoint expense) => _writes.run(() async {
    final items = await _loadCustom(expense.vehicleId);
    items.add(expense.copyWith(id: const Uuid().v4()));
    await _storage.write(_key(expense.vehicleId), jsonEncode(items));
  });
}
