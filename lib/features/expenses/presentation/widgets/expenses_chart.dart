import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/expense_point.dart';
import '../../../../core/widgets/currency_field.dart';

Map<DateTime, double> totalsByMonth(
  List<ExpensePoint> expenses,
  DateTime now, {
  String currency = 'RUB',
}) {
  final totals = {
    for (var offset = 0; offset < 6; offset++)
      DateTime(now.year, now.month - offset): 0.0,
  };
  for (final expense in expenses) {
    if (expense.currency != currency) continue;
    final month = DateTime(expense.date.year, expense.date.month);
    final value = totals[month];
    if (value != null) totals[month] = value + expense.amount;
  }
  return totals;
}

class ExpensesChart extends StatelessWidget {
  const ExpensesChart({
    super.key,
    required this.expenses,
    required this.currency,
  });
  final List<ExpensePoint> expenses;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final monthly = totalsByMonth(expenses, DateTime.now(), currency: currency);
    final max = monthly.values.fold(0.0, (a, b) => a > b ? a : b);
    final sum = monthly.values.fold(0.0, (a, b) => a + b);
    final theme = Theme.of(context);
    String money(double amount) => garageMoney(amount, currency);
    final monthLabel = DateFormat('LLLL yyyy', 'ru');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('За последние 6 месяцев', style: theme.textTheme.titleMedium),
            Text(money(sum), style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final month in monthly.entries) ...[
              Wrap(
                spacing: 10,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(monthLabel.format(month.key)),
                  Text(money(month.value)),
                ],
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : month.value / max,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
