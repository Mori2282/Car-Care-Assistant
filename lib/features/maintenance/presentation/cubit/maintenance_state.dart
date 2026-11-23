import 'package:equatable/equatable.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/maintenance_schedule.dart';

abstract class MaintenanceState extends Equatable {
  const MaintenanceState();

  @override
  List<Object?> get props => [];
}

class MaintenanceInitial extends MaintenanceState {}

class MaintenanceLoading extends MaintenanceState {}

class MaintenanceLoaded extends MaintenanceState {
  final List<MaintenanceSchedule> schedules;
  final List<MaintenanceRecord> records;

  const MaintenanceLoaded({required this.schedules, required this.records});

  MaintenanceLoaded copyWith({
    List<MaintenanceSchedule>? schedules,
    List<MaintenanceRecord>? records,
  }) {
    return MaintenanceLoaded(
      schedules: schedules ?? this.schedules,
      records: records ?? this.records,
    );
  }

  @override
  List<Object?> get props => [schedules, records];
}

class MaintenanceError extends MaintenanceState {
  final String message;

  const MaintenanceError(this.message);

  @override
  List<Object?> get props => [message];
}
