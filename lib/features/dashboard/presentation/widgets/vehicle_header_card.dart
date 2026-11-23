import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../vehicle/presentation/cubit/vehicle_cubit.dart';
import '../../../vehicle/presentation/cubit/vehicle_state.dart';

class VehicleHeaderCard extends StatelessWidget {
  final VehicleLoaded state;

  const VehicleHeaderCard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final vehicle = state.selectedVehicle!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                value: vehicle.id,
                dropdownColor: const Color(0xFF1E1E24),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                underline: const SizedBox(),
                items: state.vehicles.map((v) {
                  return DropdownMenuItem(
                    value: v.id,
                    child: Text('${v.brand} ${v.model}'),
                  );
                }).toList(),
                onChanged: (id) {
                  if (id != null) {
                    final selected = state.vehicles.firstWhere((v) => v.id == id);
                    context.read<VehicleCubit>().selectVehicle(selected);
                  }
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${vehicle.year} г.в.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Пробег', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    '${vehicle.mileage} км',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('VIN', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    vehicle.vin,
                    style: const TextStyle(fontSize: 13, fontFamily: 'Monospace', color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
