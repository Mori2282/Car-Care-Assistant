import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../maintenance/presentation/cubit/maintenance_cubit.dart';
import '../../../maintenance/presentation/cubit/maintenance_state.dart';

class UpcomingMaintenanceSection extends StatelessWidget {
  final int currentMileage;

  const UpcomingMaintenanceSection({super.key, required this.currentMileage});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaintenanceCubit, MaintenanceState>(
      builder: (context, mainState) {
        if (mainState is MaintenanceLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (mainState is MaintenanceLoaded) {
          final schedules = mainState.schedules;
          if (schedules.isEmpty) {
            return const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Нет данных о регламентных работах'),
              ),
            );
          }

          return Column(
            children: schedules.map((schedule) {
              final remaining = schedule.getRemainingMileage(currentMileage);
              final isDue = remaining <= 1000;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDue ? Colors.redAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
                    child: Icon(
                      isDue ? Icons.warning_amber_rounded : Icons.build_circle_outlined,
                      color: isDue ? Colors.redAccent : Colors.blueAccent,
                    ),
                  ),
                  title: Text(schedule.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    schedule.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDue ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDue ? Colors.redAccent : Colors.greenAccent),
                    ),
                    child: Text(
                      remaining <= 0 ? 'Просрочено' : 'Через $remaining км',
                      style: TextStyle(
                        color: isDue ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
        return const SizedBox();
      },
    );
  }
}
