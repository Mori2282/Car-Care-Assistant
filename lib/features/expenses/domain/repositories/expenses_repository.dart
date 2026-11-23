import '../models/expense_point.dart';

abstract class ExpensesRepository {
  Future<List<ExpensePoint>> getExpenses(String vehicleId);
  Future<void> addExpense(ExpensePoint expense);
}
