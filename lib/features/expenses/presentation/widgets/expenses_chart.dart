import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../domain/models/expense_point.dart';

class ExpensesChart extends StatelessWidget {
  final List<ExpensePoint> expenses;

  const ExpensesChart({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Нет данных о расходах')),
      );
    }

    final Map<int, double> monthlySums = {};
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      monthlySums[monthDate.month] = 0.0;
    }

    for (var exp in expenses) {
      if (monthlySums.containsKey(exp.date.month)) {
        monthlySums[exp.date.month] = (monthlySums[exp.date.month] ?? 0.0) + exp.amount;
      }
    }

    final List<FlSpot> spots = [];
    final List<String> monthLabels = [];
    int index = 0;

    for (int i = 5; i >= 0; i--) {
      final monthDate = DateTime(now.year, now.month - i, 1);
      monthLabels.add(DateFormat('MMM', 'ru').format(monthDate));
      final sum = monthlySums[monthDate.month] ?? 0.0;
      spots.add(FlSpot(index.toDouble(), sum));
      index++;
    }

    double maxAmount = 1000.0;
    for (var sum in monthlySums.values) {
      if (sum > maxAmount) maxAmount = sum;
    }
    maxAmount = (maxAmount / 5000).ceil() * 5000.0;
    final totalExpenses = expenses.fold<double>(0.0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Затраты (6 мес.)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 0).format(totalExpenses),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5000),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, meta) => Text('${(val / 1000).toStringAsFixed(0)}k', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (val, meta) {
                        final i = val.toInt();
                        return i >= 0 && i < monthLabels.length
                            ? Text(monthLabels[i], style: const TextStyle(color: Colors.grey, fontSize: 11))
                            : const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 5, minY: 0, maxY: maxAmount,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
