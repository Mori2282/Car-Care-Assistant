import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/expense_point.dart';
import '../../domain/repositories/expenses_repository.dart';
import '../../../maintenance/domain/repositories/maintenance_repository.dart';

class MockExpensesRepository implements ExpensesRepository {
  static const _expensesKey = 'custom_expenses_v1';
  final MaintenanceRepository _maintenanceRepository;

  MockExpensesRepository(this._maintenanceRepository);

  final List<ExpensePoint> _defaultBmwExpenses = [
    ExpensePoint(id: 'e1', date: DateTime(2026, 4, 15), amount: 12000, category: 'Fuel', vehicleId: '1'),
    ExpensePoint(id: 'e2', date: DateTime(2026, 4, 28), amount: 15000, category: 'Insurance', vehicleId: '1'),
    ExpensePoint(id: 'e3', date: DateTime(2026, 5, 10), amount: 11000, category: 'Fuel', vehicleId: '1'),
    ExpensePoint(id: 'e4', date: DateTime(2026, 5, 20), amount: 4500, category: 'Other', vehicleId: '1'),
    ExpensePoint(id: 'e5', date: DateTime(2026, 6, 12), amount: 13500, category: 'Fuel', vehicleId: '1'),
    ExpensePoint(id: 'e7', date: DateTime(2026, 7, 08), amount: 14000, category: 'Fuel', vehicleId: '1'),
    ExpensePoint(id: 'e9', date: DateTime(2026, 8, 05), amount: 11500, category: 'Fuel', vehicleId: '1'),
    ExpensePoint(id: 'e11', date: DateTime(2026, 9, 01), amount: 9800, category: 'Fuel', vehicleId: '1'),
  ];

  @override
  Future<List<ExpensePoint>> getExpenses(String vehicleId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final jsonStr = prefs.getString('${_expensesKey}_$vehicleId');
    List<ExpensePoint> customExpenses = [];
    
    if (jsonStr == null) {
      if (vehicleId == '1') {
        customExpenses = _defaultBmwExpenses;
        await _saveExpenses(prefs, vehicleId, customExpenses);
      } else {
        customExpenses = [];
      }
    } else {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      customExpenses = decoded.map((item) => ExpensePoint.fromJson(item as Map<String, dynamic>)).toList();
    }

    final maintenanceRecords = await _maintenanceRepository.getMaintenanceRecords(vehicleId);
    final List<ExpensePoint> convertedMaintExpenses = maintenanceRecords.map((rec) {
      return ExpensePoint(
        id: 'maint_${rec.id}',
        date: rec.date,
        amount: rec.cost,
        category: 'Maintenance',
        vehicleId: vehicleId,
      );
    }).toList();

    final allExpenses = [...customExpenses, ...convertedMaintExpenses];
    allExpenses.sort((a, b) => b.date.compareTo(a.date));
    return allExpenses;
  }

  @override
  Future<void> addExpense(ExpensePoint expense) async {
    final prefs = await SharedPreferences.getInstance();
    final vehicleId = expense.vehicleId;
    final list = await _getCustomExpensesOnly(prefs, vehicleId);
    
    final newExpense = expense.id.isEmpty
        ? expense.copyWith(id: const Uuid().v4())
        : expense;
    list.add(newExpense);
    await _saveExpenses(prefs, vehicleId, list);
  }

  Future<List<ExpensePoint>> _getCustomExpensesOnly(SharedPreferences prefs, String vehicleId) async {
    final jsonStr = prefs.getString('${_expensesKey}_$vehicleId');
    if (jsonStr == null) {
      return vehicleId == '1' ? List.from(_defaultBmwExpenses) : [];
    }
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((item) => ExpensePoint.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> _saveExpenses(SharedPreferences prefs, String vehicleId, List<ExpensePoint> list) async {
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString('${_expensesKey}_$vehicleId', jsonStr);
  }
}
