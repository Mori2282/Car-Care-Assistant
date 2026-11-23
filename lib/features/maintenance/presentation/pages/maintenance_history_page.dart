import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubit/maintenance_cubit.dart';
import '../cubit/maintenance_state.dart';

class MaintenanceHistoryPage extends StatefulWidget {
  final String vehicleId;

  const MaintenanceHistoryPage({super.key, required this.vehicleId});

  @override
  State<MaintenanceHistoryPage> createState() => _MaintenanceHistoryPageState();
}

class _MaintenanceHistoryPageState extends State<MaintenanceHistoryPage> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Журнал истории ТО')),
      body: BlocBuilder<MaintenanceCubit, MaintenanceState>(
        builder: (context, state) {
          if (state is MaintenanceLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is MaintenanceLoaded) {
            var records = state.records;
            if (_selectedFilter != 'all') {
              records = records.where((r) => r.type == _selectedFilter).toList();
            }

            return Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _chip('Все', 'all'),
                      const SizedBox(width: 8),
                      _chip('Масло', 'oil'),
                      const SizedBox(width: 8),
                      _chip('Фильтры', 'filter'),
                      const SizedBox(width: 8),
                      _chip('Тормоза', 'brake'),
                      const SizedBox(width: 8),
                      _chip('Подвеска', 'suspension'),
                    ],
                  ),
                ),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('Нет записей в журнале'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                  child: Icon(_getIcon(record.type), color: Theme.of(context).colorScheme.primary),
                                ),
                                title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Пробег: ${record.mileage} км | ${DateFormat('dd.MM.yyyy').format(record.date)}'),
                                trailing: Text(
                                  '${record.cost.toStringAsFixed(0)} ₽',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.greenAccent),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return const Center(child: Text('Загрузка...'));
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Запись ТО'),
      ),
    );
  }

  Widget _chip(String label, String value) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        if (selected) setState(() => _selectedFilter = value);
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'oil': return Icons.oil_barrel;
      case 'filter': return Icons.air;
      case 'brake': return Icons.car_repair;
      case 'suspension': return Icons.build;
      default: return Icons.handyman;
    }
  }

  void _showAddDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final mileageCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Новая запись ТО'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Работа')),
              TextField(controller: mileageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Пробег (км)')),
              TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Цена (₽)')),
              const SizedBox(height: 16),
              // Выбор даты через календарь
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Icon(Icons.calendar_month, size: 20, color: Colors.blueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  context.read<MaintenanceCubit>().addRecord(
                    vehicleId: widget.vehicleId,
                    title: titleCtrl.text,
                    mileage: int.tryParse(mileageCtrl.text) ?? 0,
                    cost: double.tryParse(costCtrl.text) ?? 0,
                    notes: 'Добавлено вручную',
                    type: 'other',
                    date: selectedDate, // Передаем выбранную дату
                  );
                  Navigator.pop(dialogCtx);
                }
              },
              child: const Text('ОК'),
            ),
          ],
        ),
      ),
    );
  }
}