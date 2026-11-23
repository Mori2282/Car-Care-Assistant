import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_list.dart';
import '../../../vehicle/domain/models/vehicle.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../cubit/maintenance_cubit.dart';
import '../cubit/maintenance_state.dart';

class MaintenanceHistoryPage extends StatelessWidget {
  const MaintenanceHistoryPage({super.key, required this.vehicle});
  final Vehicle vehicle;

  void _openEditor(
    BuildContext context, {
    bool plan = false,
    MaintenanceSchedule? schedule,
  }) {
    final cubit = context.read<MaintenanceCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: _MaintenanceEditor(
                vehicle: vehicle,
                plan: plan,
                schedule: schedule,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Обслуживание')),
    body: BlocBuilder<MaintenanceCubit, MaintenanceState>(
      builder: (context, state) {
        if (state is MaintenanceError) {
          return ContentList(
            children: [
              StatusCard(
                icon: Icons.error_outline,
                title: state.message,
                message: 'Попробуйте открыть данные ещё раз.',
                action: FilledButton(
                  onPressed: context.read<MaintenanceCubit>().load,
                  child: const Text('Повторить'),
                ),
              ),
            ],
          );
        }
        if (state is! MaintenanceLoaded) {
          return const Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Загрузка обслуживания',
            ),
          );
        }
        final theme = Theme.of(context);
        final schedules = [...state.schedules]..sort(
          (a, b) => a
              .getRemainingMileage(vehicle.mileage)
              .compareTo(b.getRemainingMileage(vehicle.mileage)),
        );
        final records = [...state.records]
          ..sort((a, b) => b.date.compareTo(a.date));
        return ContentList(
          children: [
            Text(
              '${vehicle.brand} ${vehicle.model}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('Записать выполненную работу'),
            ),
            const SizedBox(height: 24),
            Text('План ТО', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (schedules.isEmpty)
              const Text(
                'Добавьте работы и интервалы из руководства к своему автомобилю.',
              ),
            for (final item in schedules)
              Card(
                child: ListTile(
                  leading: Icon(
                    item.isDue(vehicle.mileage)
                        ? Icons.schedule
                        : Icons.event_available_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(_scheduleSummary(item)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditor(context, schedule: item),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _openEditor(context, plan: true),
              icon: const Icon(Icons.event_repeat),
              label: const Text('Добавить работу в план'),
            ),
            const SizedBox(height: 24),
            Text('История работ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Text('Здесь появятся выполненные работы.'),
            for (final record in records)
              Card(
                child: ListTile(
                  title: Text(record.title),
                  subtitle: Text(
                    [
                      '${DateFormat('dd.MM.yyyy').format(record.date)} · ${record.mileage} км',
                      if (record.cost > 0)
                        'Стоимость: ${NumberFormat.currency(locale: 'ru', symbol: '₽').format(record.cost)}',
                      if (record.notes.isNotEmpty) record.notes,
                    ].join('\n'),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  String _scheduleSummary(MaintenanceSchedule item) {
    final remaining = item.getRemainingMileage(vehicle.mileage);
    if (remaining <= 0) {
      return 'Пора выполнить · каждые ${item.intervalMileage} км';
    }
    return 'Через $remaining км · каждые ${item.intervalMileage} км';
  }
}

class _MaintenanceEditor extends StatefulWidget {
  const _MaintenanceEditor({
    required this.vehicle,
    required this.plan,
    this.schedule,
  });
  final Vehicle vehicle;
  final bool plan;
  final MaintenanceSchedule? schedule;

  @override
  State<_MaintenanceEditor> createState() => _MaintenanceEditorState();
}

class _MaintenanceEditorState extends State<_MaintenanceEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.schedule?.title);
  late final _mileage = TextEditingController(
    text: widget.vehicle.mileage.toString(),
  );
  final _interval = TextEditingController();
  final _cost = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  bool _failed = false;

  @override
  void dispose() {
    for (final controller in [_title, _mileage, _interval, _cost, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final cubit = context.read<MaintenanceCubit>();
    final mileage = int.parse(_mileage.text);
    final cost = double.tryParse(_cost.text.trim().replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      if (widget.plan) {
        await cubit.addSchedule(
          MaintenanceSchedule(
            id: '',
            title: _title.text.trim(),
            intervalMileage: int.parse(_interval.text),
            lastCompletedMileage: mileage,
            description: '',
          ),
        );
      } else {
        await cubit.addRecord(
          MaintenanceRecord(
            id: '',
            vehicleId: widget.vehicle.id,
            title: _title.text.trim(),
            mileage: mileage,
            date: _date,
            cost: cost,
            notes: _notes.text.trim(),
            type: 'other',
          ),
          scheduleId: widget.schedule?.id,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.plan ? 'Добавить в план' : 'Записать работу';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _form,
        child: ContentList(
          children: [
            TextFormField(
              controller: _title,
              readOnly: widget.schedule != null,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Название работы',
                counterText: '',
              ),
              validator:
                  (value) =>
                      (value ?? '').trim().isEmpty ? 'Введите название' : null,
            ),
            const SizedBox(height: 12),
            _numberField(
              _mileage,
              widget.plan
                  ? 'Пробег последнего ТО, км'
                  : 'Пробег при выполнении, км',
            ),
            const SizedBox(height: 12),
            if (widget.plan)
              _numberField(_interval, 'Повторять каждые, км', minimum: 1)
            else ...[
              TextFormField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Стоимость, ₽ (если известна)',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final amount = double.tryParse(text.replaceAll(',', '.'));
                  return amount == null || !amount.isFinite || amount < 0
                      ? 'Введите корректную сумму'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Заметка (необязательно)',
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _date,
                            firstDate: DateTime(1900),
                            lastDate: now,
                          );
                          if (picked != null && mounted) {
                            setState(() => _date = picked);
                          }
                        },
                icon: const Icon(Icons.calendar_month),
                label: Text('Дата: ${DateFormat('dd.MM.yyyy').format(_date)}'),
              ),
            ],
            const SizedBox(height: 20),
            if (_failed)
              const Text('Не удалось сохранить. Попробуйте ещё раз.'),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label, {
    int minimum = 0,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(9),
    ],
    decoration: InputDecoration(labelText: label),
    validator:
        (value) =>
            (int.tryParse(value ?? '') ?? -1) < minimum
                ? 'Введите корректное значение'
                : null,
  );
}
