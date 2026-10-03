import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/async/async_value.dart';
import '../attendance/data/attendance_repository.dart';
import '../employee/data/employee_repository.dart';
import '../notifications/data/notifications_repository.dart';
import '../requests/application/requests_cubit.dart';
import '../requests/data/requests_repository.dart';

/// Today's schedule plus the attendance record, shared by Home and Attendance.
class TodayStatus {
  const TodayStatus(this.schedule, this.record);

  final TodaySchedule schedule;
  final AttendanceRecord? record;

  bool get needsClockIn => schedule.scheduled && record?.clockInAt == null;
  bool get needsClockOut =>
      record?.clockInAt != null && record?.clockOutAt == null;
  bool get done => record?.clockOutAt != null;

  /// Whether [now] is inside the window for the pending action. The API
  /// enforces the same windows; this only avoids offering a doomed action.
  WindowState window(DateTime now) {
    final (opens, closes) = needsClockOut
        ? (schedule.clockOutOpensAt, schedule.clockOutClosesAt)
        : (schedule.clockInOpensAt, schedule.clockInClosesAt);
    if (opens != null && now.isBefore(opens)) return WindowState.notOpen;
    if (closes != null && now.isAfter(closes)) return WindowState.closed;
    return WindowState.open;
  }
}

class ProfileCubit extends LoadCubit<EmployeeProfile?> {
  ProfileCubit(EmployeeRepository repository) : super(repository.me);
}

class TodayCubit extends LoadCubit<TodayStatus> {
  TodayCubit(AttendanceRepository repository)
      : super(() async {
          final results = await Future.wait<Object?>([
            repository.today(),
            repository.todayRecord(),
          ]);
          return TodayStatus(
            results[0]! as TodaySchedule,
            results[1] as AttendanceRecord?,
          );
        });
}

enum WindowState { notOpen, open, closed }

/// Session-scoped state created when a user signs in and dropped on sign-out.
class SignedInScope extends StatelessWidget {
  const SignedInScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ProfileCubit(context.read<EmployeeRepository>()),
        ),
        BlocProvider(
          create: (context) => TodayCubit(context.read<AttendanceRepository>()),
        ),
        BlocProvider(
          create: (context) => RequestsCubit(context.read<RequestsRepository>()),
        ),
        BlocProvider(
          create: (context) =>
              UnreadCountCubit(context.read<NotificationsRepository>())
                ..refresh(),
        ),
      ],
      child: child,
    );
  }
}
