import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../vehicle/presentation/cubit/vehicle_cubit.dart';
import '../../../vehicle/presentation/cubit/vehicle_state.dart';
import '../../../vehicle/presentation/pages/add_vehicle_page.dart';
import '../../../maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../../maintenance/presentation/pages/maintenance_history_page.dart';
import '../../../expenses/presentation/cubit/expenses_cubit.dart';
import '../../../expenses/presentation/cubit/expenses_state.dart';
import '../../../expenses/presentation/widgets/expenses_chart.dart';
import '../widgets/vehicle_header_card.dart';
import '../widgets/upcoming_maintenance_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    context.read<VehicleCubit>().loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Care Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Добавить авто / Захват VIN',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddVehiclePage()),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<VehicleCubit, VehicleState>(
        listener: (context, state) {
          if (state is VehicleLoaded && state.selectedVehicle != null) {
            final vId = state.selectedVehicle!.id;
            context.read<MaintenanceCubit>().loadMaintenanceData(vId);
            context.read<ExpensesCubit>().loadExpenses(vId);
          }
        },
        builder: (context, state) {
          if (state is VehicleLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is VehicleLoaded) {
            final vehicle = state.selectedVehicle;
            if (vehicle == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Гараж пуст'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddVehiclePage()),
                        );
                      },
                      child: const Text('Добавить первое авто'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<VehicleCubit>().loadVehicles();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VehicleHeaderCard(state: state),
                    const SizedBox(height: 20),
                    BlocBuilder<ExpensesCubit, ExpensesState>(
                      builder: (context, expState) {
                        if (expState is ExpensesLoaded) {
                          return ExpensesChart(expenses: expState.expenses);
                        }
                        return const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Регламентные работы (ТО)',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MaintenanceHistoryPage(vehicleId: vehicle.id),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('История'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    UpcomingMaintenanceSection(currentMileage: vehicle.mileage),
                  ],
                ),
              ),
            );
          }
          return const Center(child: Text('Ошибка загрузки'));
        },
      ),
    );
  }
}
