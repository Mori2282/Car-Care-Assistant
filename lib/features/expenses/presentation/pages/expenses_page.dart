import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_list.dart';
import '../../../vehicle/domain/models/vehicle.dart';
import '../../domain/models/expense_point.dart';
import '../cubit/expenses_cubit.dart';
import '../cubit/expenses_state.dart';
import '../widgets/expenses_chart.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Расходы')),
    body: BlocBuilder<ExpensesCubit, ExpensesState>(
      builder: (context, state) {
        if (state is ExpensesError) {
          return ContentList(
            children: [
              StatusCard(
                icon: Icons.error_outline,
                title: state.message,
                message: 'Попробуйте открыть данные ещё раз.',
                action: FilledButton(
                  onPressed: context.read<ExpensesCubit>().load,
                  child: const Text('Повторить'),
                ),
              ),
            ],
          );
        }
        if (state is! ExpensesLoaded) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Загрузка расходов',
            ),
          );
        }
        final theme = Theme.of(context);
        final money = NumberFormat.currency(locale: 'ru', symbol: '₽');
        return ContentList(
          children: [
            Text(
              '${vehicle.brand} ${vehicle.model}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                final cubit = context.read<ExpensesCubit>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => BlocProvider.value(
                          value: cubit,
                          child: _ExpenseEditor(vehicle: vehicle),
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Добавить расход'),
            ),
            const SizedBox(height: 20),
            if (state.expenses.isEmpty)
              const StatusCard(
                icon: Icons.payments_outlined,
                title: 'Расходов ещё нет',
                message:
                    'Добавьте покупку или укажите стоимость при записи работы в журнале обслуживания.',
              )
            else ...[
              ExpensesChart(expenses: state.expenses),
              const SizedBox(height: 16),
              Text('История расходов', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final expense in state.expenses)
                Card(
                  child: ListTile(
                    title: Text(expense.category),
                    subtitle: Text(
                      '${money.format(expense.amount)} · ${DateFormat('dd.MM.yyyy').format(expense.date)}',
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({required this.vehicle});
  final Vehicle vehicle;

  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  final _form = GlobalKey<FormState>();
  String _description = '';
  double _amount = 0;
  DateTime _date = DateTime.now();
  bool _saving = false, _error = false;

  double? _parse(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      _saving = true;
      _error = false;
    });
    try {
      await context.read<ExpensesCubit>().addExpense(
        ExpensePoint(
          id: '',
          date: _date,
          amount: _amount,
          category: _description,
          vehicleId: widget.vehicle.id,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Добавить расход')),
    body: Form(
      key: _form,
      child: ContentList(
        children: [
          TextFormField(
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'На что потратили',
              counterText: '',
            ),
            validator:
                (value) =>
                    (value ?? '').trim().isEmpty ? 'Введите описание' : null,
            onSaved: (value) => _description = value!.trim(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Сумма, ₽'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              final amount = _parse(value);
              return amount == null || !amount.isFinite || amount <= 0
                  ? 'Введите сумму больше нуля'
                  : null;
            },
            onSaved: (value) => _amount = _parse(value)!,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _saving
                    ? null
                    : () async {
                      final value = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (value != null && mounted) {
                        setState(() => _date = value);
                      }
                    },
            icon: const Icon(Icons.calendar_month),
            label: Text('Дата: ${DateFormat('dd.MM.yyyy').format(_date)}'),
          ),
          const SizedBox(height: 16),
          if (_error)
            const Text('Не удалось сохранить расход. Попробуйте ещё раз.'),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Сохраняем…' : 'Сохранить расход'),
          ),
        ],
      ),
    ),
  );
}
