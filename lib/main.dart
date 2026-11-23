import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/catalog/catalog_api.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'core/storage/garage_storage.dart';
import 'core/notifications/maintenance_reminders.dart';
import 'features/vehicle/domain/repositories/vehicle_repository.dart';
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
  runApp(CarCareApp(storage: SqliteGarageStorage()));
}

class CarCareApp extends StatelessWidget {
  const CarCareApp({
    super.key,
    this.storage = const PreferencesGarageStorage(),
  });
  final GarageStorage storage;
  static final _lightTheme = AppTheme.create(Brightness.light);
  static final _darkTheme = AppTheme.create(Brightness.dark);

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<GarageStorage>.value(value: storage),
      RepositoryProvider<VehicleRepository>(
        create: (_) => LocalVehicleRepository(storage: storage),
      ),
      RepositoryProvider(create: (_) => CatalogApi()),
      RepositoryProvider(
        create: (context) => VinLookup(context.read<CatalogApi>()),
      ),
      RepositoryProvider(
        create:
            (context) =>
                PartsRepository(context.read<CatalogApi>(), storage: storage),
      ),
      RepositoryProvider<MaintenanceRepository>(
        create: (_) => LocalMaintenanceRepository(storage: storage),
      ),
      RepositoryProvider<ExpensesRepository>(
        create:
            (context) => LocalExpensesRepository(
              context.read<MaintenanceRepository>(),
              storage: storage,
            ),
      ),
      RepositoryProvider(
        create:
            (context) => MaintenanceReminders(
              context.read<VehicleRepository>(),
              context.read<MaintenanceRepository>(),
            )..refreshQuietly(),
      ),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(
          create:
              (context) =>
                  VehicleCubit(context.read<VehicleRepository>())
                    ..loadVehicles(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder:
            (context, mode) => MaterialApp(
              title: 'Car Care Assistant',
              debugShowCheckedModeBanner: false,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: _lightTheme,
              darkTheme: _darkTheme,
              themeMode: mode,
              home: const DashboardPage(),
            ),
      ),
    ),
  );
}
