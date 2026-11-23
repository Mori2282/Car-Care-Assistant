import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/expense_point.dart';
import '../../domain/repositories/expenses_repository.dart';
import 'expenses_state.dart';

class ExpensesCubit extends Cubit<ExpensesState> {
  ExpensesCubit(this._repository, this.vehicleId) : super(ExpensesInitial());

  final ExpensesRepository _repository;
  final String vehicleId;

  Future<void> load() async {
    if (state is! ExpensesLoaded) emit(ExpensesLoading());
    try {
      final expenses = await _repository.getExpenses(vehicleId);
      if (!isClosed) emit(ExpensesLoaded(expenses: expenses));
    } catch (_) {
      if (!isClosed) emit(const ExpensesError('Не удалось загрузить расходы'));
    }
  }

  Future<void> addExpense(ExpensePoint expense) async {
    await _repository.addExpense(expense);
    if (!isClosed) await load();
  }
}
