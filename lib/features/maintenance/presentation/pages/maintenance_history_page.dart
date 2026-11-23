import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_list.dart';
import '../../../../core/widgets/currency_field.dart';
import '../../../vehicle/domain/models/vehicle.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';
import '../cubit/maintenance_cubit.dart';
import '../cubit/maintenance_state.dart';

class MaintenanceHistoryPage extends StatelessWidget {
  const MaintenanceHistoryPage({super.key, required this.vehicle});
  final Vehicle vehicle;

  void _edit(
    BuildContext context, {
    bool plan = false,
    MaintenanceSchedule? schedule,
    MaintenanceRecord? record,
  }) {
    final cubit = context.read<MaintenanceCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: _Editor(
                vehicle: vehicle,
                plan: plan,
                schedule: schedule,
                record: record,
              ),
            ),
      ),
    );
  }

  Future<void> _remove(
    BuildContext context,
    String title,
    Future<void> Function() operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialog) => AlertDialog(
            title: Text('Удалить «$title»?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await operation();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось удалить запись.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Обслуживание')),
    body: BlocBuilder<MaintenanceCubit, MaintenanceState>(
      builder: (context, state) {
        final cubit = context.read<MaintenanceCubit>();
        if (state is MaintenanceError) {
          return ContentList(
            children: [
              StatusCard(
                icon: Icons.error_outline,
                title: state.message,
                message: 'Попробуйте открыть данные ещё раз.',
                action: FilledButton(
                  onPressed: cubit.load,
                  child: const Text('Повторить'),
                ),
              ),
            ],
          );
        }
        if (state is! MaintenanceLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        final theme = Theme.of(context);
        final next = nearestMaintenance(
          state.schedules,
          vehicle.mileage,
          DateTime.now(),
        );
        final schedules = [
          if (next != null) next,
          ...state.schedules.where((item) => item != next),
        ];
        return ContentList(
          children: [
            Text(
              '${vehicle.brand} ${vehicle.model}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('Записать выполненную работу'),
            ),
            const SizedBox(height: 24),
            Text('План ТО', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (schedules.isEmpty)
              const Text('Добавьте сроки работ по руководству к автомобилю.'),
            for (final item in schedules)
              Card(
                child: ListTile(
                  leading: Icon(
                    item.isDue(vehicle.mileage)
                        ? Icons.schedule
                        : Icons.event_available_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.dueSummary(vehicle.mileage)),
                  onTap: () => _edit(context, schedule: item),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Действия с работой',
                    onSelected:
                        (action) =>
                            action == 'edit'
                                ? _edit(context, plan: true, schedule: item)
                                : _remove(
                                  context,
                                  item.title,
                                  () => cubit.removeSchedule(item.id),
                                ),
                    itemBuilder:
                        (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Изменить срок'),
                          ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text('Удалить из плана'),
                          ),
                        ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _edit(context, plan: true),
              icon: const Icon(Icons.event_repeat),
              label: const Text('Добавить работу в план'),
            ),
            const SizedBox(height: 24),
            Text('История работ', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            if (state.records.isEmpty)
              const Text('Здесь появятся выполненные работы.'),
            for (final record in state.records)
              Card(
                child: ListTile(
                  title: Text(record.title),
                  subtitle: Text(
                    [
                      '${DateFormat('dd.MM.yyyy').format(record.date)} · ${record.mileage} км',
                      if (record.cost > 0)
                        garageMoney(record.cost, record.currency),
                      if (record.notes.isNotEmpty) record.notes,
                    ].join('\n'),
                  ),
                  onTap: () => _edit(context, record: record),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Удалить запись',
                    onPressed:
                        () => _remove(
                          context,
                          record.title,
                          () => cubit.removeRecord(record.id),
                        ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.vehicle,
    required this.plan,
    this.schedule,
    this.record,
  });
  final Vehicle vehicle;
  final bool plan;
  final MaintenanceSchedule? schedule;
  final MaintenanceRecord? record;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.record?.title ?? widget.schedule?.title,
  );
  late final _mileage = TextEditingController(
    text:
        (widget.record?.mileage ??
                (widget.plan ? widget.schedule?.lastCompletedMileage : null) ??
                widget.vehicle.mileage)
            .toString(),
  );
  late final _km = TextEditingController(
    text: widget.schedule?.intervalMileage.toString(),
  );
  late final _days = TextEditingController(
    text: widget.schedule?.intervalDays.toString(),
  );
  late final _cost = TextEditingController(
    text: widget.record?.cost.toString(),
  );
  late final _notes = TextEditingController(text: widget.record?.notes);
  late DateTime _date =
      widget.record?.date ??
      (widget.plan ? widget.schedule?.lastCompletedOn : null) ??
      DateTime.now();
  late String _currency = widget.record?.currency ?? 'RUB';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_title, _mileage, _km, _days, _cost, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final km = int.tryParse(_km.text) ?? 0;
    final days = int.tryParse(_days.text) ?? 0;
    if (widget.plan && km == 0 && days == 0) {
      setState(() => _error = 'Укажите интервал в километрах или днях.');
      return;
    }
    final cubit = context.read<MaintenanceCubit>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final mileage = int.parse(_mileage.text);
      if (widget.plan) {
        await cubit.addSchedule(
          MaintenanceSchedule(
            id: widget.schedule?.id ?? '',
            title: _title.text.trim(),
            intervalMileage: km,
            intervalDays: days,
            description: widget.schedule?.description ?? '',
            lastCompletedMileage: mileage,
            lastCompletedOn: _date,
          ),
        );
      } else {
        await cubit.addRecord(
          MaintenanceRecord(
            id: widget.record?.id ?? '',
            vehicleId: widget.vehicle.id,
            title: _title.text.trim(),
            mileage: mileage,
            date: _date,
            cost: _amount() ?? 0,
            currency: _currency,
            notes: _notes.text.trim(),
            type: widget.record?.type ?? 'other',
          ),
          scheduleId: widget.schedule?.id,
          replaceExisting: widget.record != null,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Не удалось сохранить. Попробуйте снова.';
        });
      }
    }
  }

  double? _amount() => double.tryParse(_cost.text.trim().replaceAll(',', '.'));

  Widget _number(
    TextEditingController controller,
    String title, {
    bool requiredField = false,
    int limit = 9,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(limit),
    ],
    decoration: InputDecoration(labelText: title),
    validator:
        (value) =>
            requiredField && int.tryParse(value ?? '') == null
                ? 'Заполните поле'
                : null,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.plan ? 'Срок обслуживания' : 'Запись об обслуживании'),
    ),
    body: Form(
      key: _form,
      child: ContentList(
        children: [
          TextFormField(
            controller: _title,
            readOnly: !widget.plan && widget.schedule != null,
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
          _number(
            _mileage,
            widget.plan
                ? 'Пробег последнего ТО, км'
                : 'Пробег при выполнении, км',
            requiredField: true,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _saving
                    ? null
                    : () async {
                      final last = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date.isAfter(last) ? last : _date,
                        firstDate: DateTime(1900),
                        lastDate: last,
                      );
                      if (picked != null && mounted) {
                        setState(() => _date = picked);
                      }
                    },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              '${widget.plan ? 'Дата последнего ТО' : 'Дата'}: ${DateFormat('dd.MM.yyyy').format(_date)}',
            ),
          ),
          const SizedBox(height: 12),
          if (widget.plan) ...[
            _number(_km, 'Интервал по пробегу, км'),
            const SizedBox(height: 12),
            _number(_days, 'Интервал по времени, дней', limit: 4),
            const SizedBox(height: 8),
            const Text(
              'Укажите хотя бы один интервал. Если указаны оба, ориентируйтесь на ближайший срок.',
            ),
          ] else ...[
            TextFormField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Стоимость (если известна)',
              ),
              validator: (_) {
                if (_cost.text.trim().isEmpty) return null;
                final amount = _amount();
                return amount == null || !amount.isFinite || amount < 0
                    ? 'Введите корректную сумму'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            CurrencyField(
              value: _currency,
              onChanged: (value) => setState(() => _currency = value),
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
          ],
          const SizedBox(height: 12),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
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
