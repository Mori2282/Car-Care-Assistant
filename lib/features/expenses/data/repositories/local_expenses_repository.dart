import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/storage/serial_writes.dart';
import 'package:uuid/uuid.dart';
import '../../../maintenance/domain/repositories/maintenance_repository.dart';
import '../../domain/models/expense_point.dart';
import '../../domain/repositories/expenses_repository.dart';

class LocalExpensesRepository implements ExpensesRepository {
  final _writes = SerialWrites();
  LocalExpensesRepository(this._maintenance);
  final MaintenanceRepository _maintenance;

  String _key(String id) => 'custom_expenses_v1_$id';

  Future<List<ExpensePoint>> _loadCustom(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(id));
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
            category: record.title,
            vehicleId: vehicleId,
          ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> addExpense(ExpensePoint expense) => _writes.run(() async {
    final prefs = await SharedPreferences.getInstance();
    final items = await _loadCustom(expense.vehicleId);
    items.add(expense.copyWith(id: const Uuid().v4()));
    if (!await prefs.setString(_key(expense.vehicleId), jsonEncode(items))) {
      throw StateError('Expense storage write failed');
    }
  });
}
