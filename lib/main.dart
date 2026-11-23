import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'features/vehicle/data/repositories/mock_vehicle_repository.dart';
import 'features/vehicle/presentation/cubit/vehicle_cubit.dart';
import 'features/maintenance/data/repositories/mock_maintenance_repository.dart';
import 'features/maintenance/presentation/cubit/maintenance_cubit.dart';
import 'features/expenses/data/repositories/mock_expenses_repository.dart';
import 'features/expenses/presentation/cubit/expenses_cubit.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  runApp(const CarCareApp());
}

class CarCareApp extends StatelessWidget {
  const CarCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final vehicleRepo = MockVehicleRepository();
    final maintenanceRepo = MockMaintenanceRepository();
    final expensesRepo = MockExpensesRepository(maintenanceRepo);

    return MultiBlocProvider(
      providers: [
        BlocProvider<VehicleCubit>(
          create: (_) => VehicleCubit(vehicleRepo),
        ),
        BlocProvider<MaintenanceCubit>(
          create: (_) => MaintenanceCubit(maintenanceRepo),
        ),
        BlocProvider<ExpensesCubit>(
          create: (_) => ExpensesCubit(expensesRepo),
        ),
      ],
      child: MaterialApp(
        title: 'Car Care Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const DashboardPage(),
      ),
    );
  }
}
