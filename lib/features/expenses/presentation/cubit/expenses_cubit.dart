import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/expense_point.dart';
import '../../domain/repositories/expenses_repository.dart';
import 'expenses_state.dart';

class ExpensesCubit extends Cubit<ExpensesState> {
  final ExpensesRepository _expensesRepository;

  ExpensesCubit(this._expensesRepository) : super(ExpensesInitial());

  Future<void> loadExpenses(String vehicleId) async {
    emit(ExpensesLoading());
    try {
      final expenses = await _expensesRepository.getExpenses(vehicleId);
      emit(ExpensesLoaded(expenses: expenses));
    } catch (e) {
      emit(ExpensesError('Не удалось загрузить расходы: ${e.toString()}'));
    }
  }

  Future<void> addExpense({
    required DateTime date,
    required double amount,
    required String category,
    required String vehicleId,
  }) async {
    if (state is ExpensesLoaded) {
      try {
        final newExpense = ExpensePoint(
          id: '',
          date: date,
          amount: amount,
          category: category,
          vehicleId: vehicleId, // <-- Передаем жесткую привязку к машине!
        );
        await _expensesRepository.addExpense(newExpense);
        
        final expenses = await _expensesRepository.getExpenses(vehicleId);
        emit(ExpensesLoaded(expenses: expenses));
      } catch (e) {
        emit(ExpensesError('Не удалось добавить расход: ${e.toString()}'));
      }
    }
  }
}