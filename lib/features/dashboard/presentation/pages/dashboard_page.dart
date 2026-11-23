import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/notifications/maintenance_reminders.dart';
import '../../../maintenance/domain/models/maintenance_schedule.dart';
import 'garage_settings_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_list.dart';
import '../../../expenses/domain/repositories/expenses_repository.dart';
import '../../../expenses/presentation/cubit/expenses_cubit.dart';
import '../../../expenses/presentation/cubit/expenses_state.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../maintenance/domain/repositories/maintenance_repository.dart';
import '../../../maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../../maintenance/presentation/cubit/maintenance_state.dart';
import '../../../maintenance/presentation/pages/maintenance_history_page.dart';
import '../../../parts/presentation/parts_page.dart';
import '../../../vehicle/domain/models/vehicle.dart';
import '../../../vehicle/presentation/cubit/vehicle_cubit.dart';
import '../../../vehicle/presentation/cubit/vehicle_state.dart';
import '../../../vehicle/presentation/pages/add_vehicle_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  static void _edit(BuildContext context, [Vehicle? vehicle]) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddVehiclePage(vehicle: vehicle)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Мой гараж'),
      actions: [
        IconButton(
          tooltip: 'Настройки гаража',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () async {
            final restored = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const GarageSettingsPage()),
            );
            if (restored == true && context.mounted) {
              await context.read<VehicleCubit>().loadVehicles(fromBackup: true);
            }
          },
        ),
        IconButton(
          onPressed: () => _edit(context),
          tooltip: 'Добавить автомобиль',
          icon: const Icon(Icons.add_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: BlocBuilder<VehicleCubit, VehicleState>(
      builder: (context, state) {
        if (state is VehicleError) {
          return ContentList(
            children: [
              StatusCard(
                icon: Icons.error_outline,
                title: 'Гараж недоступен',
                message: state.message,
                action: FilledButton(
                  onPressed: context.read<VehicleCubit>().loadVehicles,
                  child: const Text('Повторить'),
                ),
              ),
            ],
          );
        }
        if (state is! VehicleLoaded) {
          return const Center(
            child: CircularProgressIndicator(semanticsLabel: 'Загрузка гаража'),
          );
        }
        final current = state.selectedVehicle;
        if (current == null) {
          return ContentList(
            children: [
              StatusCard(
                icon: Icons.directions_car_outlined,
                title: 'Добавьте свой автомобиль',
                message:
                    'Ведите историю обслуживания, записывайте расходы и сохраняйте нужные запчасти.',
                action: FilledButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить авто'),
                ),
              ),
            ],
          );
        }
        final disableAnimations = MediaQuery.disableAnimationsOf(context);
        return AnimatedSwitcher(
          duration:
              disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
          child: MultiBlocProvider(
            key: ValueKey(current.id),
            providers: [
              BlocProvider(
                create:
                    (context) => MaintenanceCubit(
                      context.read<MaintenanceRepository>(),
                      current.id,
                      onChanged:
                          context.read<MaintenanceReminders>().refreshQuietly,
                    )..load(),
              ),
              BlocProvider(
                create:
                    (context) => ExpensesCubit(
                      context.read<ExpensesRepository>(),
                      current.id,
                    )..load(),
              ),
            ],
            child: _GarageContent(vehicle: current, vehicles: state.vehicles),
          ),
        );
      },
    ),
  );
}

class _GarageContent extends StatelessWidget {
  const _GarageContent({required this.vehicle, required this.vehicles});
  final Vehicle vehicle;
  final List<Vehicle> vehicles;

  Future<void> _pickVehicle(BuildContext context) async {
    final selected = await showModalBottomSheet<Vehicle>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => FractionallySizedBox(
            heightFactor: 0.72,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  'Выберите автомобиль',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final item in vehicles)
                  Card(
                    child: ListTile(
                      selected: item.id == vehicle.id,
                      title: Text('${item.brand} ${item.model}'),
                      subtitle: Text(
                        [
                          item.year.toString(),
                          item.vin,
                        ].where((v) => v.isNotEmpty).join(' · '),
                      ),
                      leading: Icon(
                        item.id == vehicle.id
                            ? Icons.check_circle
                            : Icons.directions_car_outlined,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    ),
                  ),
              ],
            ),
          ),
    );
    if (selected != null && context.mounted) {
      await context.read<VehicleCubit>().selectVehicle(selected);
    }
  }

  Future<void> _openMaintenance(BuildContext context) async {
    final maintenance = context.read<MaintenanceCubit>();
    final expenses = context.read<ExpensesCubit>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: maintenance,
              child: MaintenanceHistoryPage(vehicle: vehicle),
            ),
      ),
    );
    if (context.mounted) await expenses.load();
  }

  void _openExpenses(BuildContext context) {
    final cubit = context.read<ExpensesCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: ExpensesPage(vehicle: vehicle),
            ),
      ),
    );
  }

  Future<void> _updateMileage(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _MileagePage(vehicle: vehicle)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mileage = NumberFormat.decimalPattern('ru').format(vehicle.mileage);
    return ContentList(
      children: [
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.directions_car_filled_rounded,
                  size: 36,
                  color: colors.onPrimaryContainer,
                ),
                const SizedBox(height: 12),
                Text(
                  '${vehicle.brand} ${vehicle.model}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${vehicle.year} г. · $mileage км',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                if (vehicle.variant.isNotEmpty)
                  Text(
                    vehicle.variant,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                if (vehicle.vin.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    vehicle.vin,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => DashboardPage._edit(context, vehicle),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Редактировать'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _updateMileage(context),
                      icon: const Icon(Icons.speed),
                      label: const Text('Обновить пробег'),
                    ),
                    if (vehicles.length > 1)
                      OutlinedButton.icon(
                        onPressed: () => _pickVehicle(context),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Сменить авто'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed:
              () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PartsPage(vehicle: vehicle)),
              ),
          icon: const Icon(Icons.search),
          label: const Text('Найти запчасть'),
        ),
        const SizedBox(height: 12),
        BlocBuilder<MaintenanceCubit, MaintenanceState>(
          builder: (context, state) {
            final next =
                state is MaintenanceLoaded
                    ? nearestMaintenance(
                      state.schedules,
                      vehicle.mileage,
                      DateTime.now(),
                    )
                    : null;
            return _action(
              context,
              icon: Icons.build_outlined,
              title:
                  next == null ? 'Обслуживание' : 'Следующее ТО: ${next.title}',
              subtitle:
                  next == null
                      ? 'Записать работу или добавить напоминание'
                      : next.dueSummary(vehicle.mileage),
              onTap: () => _openMaintenance(context),
            );
          },
        ),
        BlocBuilder<ExpensesCubit, ExpensesState>(
          builder:
              (context, state) => _action(
                context,
                icon: Icons.payments_outlined,
                title: 'Расходы',
                subtitle:
                    state is ExpensesLoaded && state.expenses.isNotEmpty
                        ? 'Записей о расходах: ${state.expenses.length}'
                        : 'Топливо, обслуживание и другие траты',
                onTap: () => _openExpenses(context),
              ),
        ),
      ],
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: Icon(
        icon,
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _MileagePage extends StatefulWidget {
  const _MileagePage({required this.vehicle});
  final Vehicle vehicle;

  @override
  State<_MileagePage> createState() => _MileagePageState();
}

class _MileagePageState extends State<_MileagePage> {
  final _form = GlobalKey<FormState>();
  late final _value = TextEditingController(
    text: widget.vehicle.mileage.toString(),
  );
  bool _saving = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final mileage = int.parse(_value.text);
    final repository = context.read<MaintenanceRepository>();
    final cubit = context.read<VehicleCubit>();
    setState(() => _saving = true);
    try {
      final data = await repository.getMaintenance(widget.vehicle.id);
      await cubit.saveVehicle(widget.vehicle.copyWith(mileage: mileage));
      if (!mounted) return;
      final crossing = data.schedules.any(
        (item) =>
            item.intervalMileage > 0 &&
            item.getRemainingMileage(widget.vehicle.mileage) > 1000 &&
            item.getRemainingMileage(mileage) <= 1000,
      );
      Navigator.pop(context);
      if (crossing) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('По пробегу скоро ТО. Проверьте план в гараже.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пробег не сохранился. Попробуйте ещё раз.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Обновить пробег')),
    body: Form(
      key: _form,
      child: ContentList(
        children: [
          TextFormField(
            controller: _value,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: const InputDecoration(
              labelText: 'Показание одометра, км',
            ),
            validator:
                (value) =>
                    int.tryParse(value ?? '') == null ? 'Введите пробег' : null,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Сохранить пробег'),
          ),
        ],
      ),
    ),
  );
}
