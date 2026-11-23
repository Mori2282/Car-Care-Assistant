import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/catalog/catalog_api.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/expenses/data/repositories/local_expenses_repository.dart';
import 'features/expenses/domain/repositories/expenses_repository.dart';
import 'features/maintenance/data/repositories/local_maintenance_repository.dart';
import 'features/maintenance/domain/repositories/maintenance_repository.dart';
import 'features/parts/data/parts_repository.dart';
import 'features/vehicle/data/datasources/nhtsa_api_service.dart';
import 'features/vehicle/data/repositories/local_vehicle_repository.dart';
import 'features/vehicle/presentation/cubit/vehicle_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  runApp(const CarCareApp());
}

class CarCareApp extends StatelessWidget {
  const CarCareApp({super.key});

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider(create: (_) => CatalogApi()),
      RepositoryProvider(
        create: (context) => VinLookup(context.read<CatalogApi>()),
      ),
      RepositoryProvider(
        create: (context) => PartsRepository(context.read<CatalogApi>()),
      ),
      RepositoryProvider<MaintenanceRepository>(
        create: (_) => LocalMaintenanceRepository(),
      ),
      RepositoryProvider<ExpensesRepository>(
        create:
            (context) =>
                LocalExpensesRepository(context.read<MaintenanceRepository>()),
      ),
    ],
    child: BlocProvider(
      create: (_) => VehicleCubit(LocalVehicleRepository())..loadVehicles(),
      child: MaterialApp(
        title: 'Car Care Assistant',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.create(Brightness.light),
        darkTheme: AppTheme.create(Brightness.dark),
        home: const DashboardPage(),
      ),
    ),
  );
}
