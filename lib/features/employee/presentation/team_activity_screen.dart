import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/state_views.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/application/auth_cubit.dart';
import '../data/directory_repository.dart';

/// Today's attendance of the manager's direct reports.
class TeamActivityScreen extends StatelessWidget {
  const TeamActivityScreen({required this.reports, super.key});

  final List<Colleague> reports;

  @override
  Widget build(BuildContext context) {
    final timezone = context.read<AuthCubit>().state.user?.organization.timezone;
    final today = Clock.iso(Clock.today(timezone));
    return BlocProvider(
      create: (context) => LoadCubit<List<AttendanceRecord>>(
        () => context.read<AttendanceRepository>().team(today),
      ),
      child: Builder(
        builder: (context) {
          final cubit = context.watch<LoadCubit<List<AttendanceRecord>>>();
          return Scaffold(
            appBar: AppBar(title: const Text('Team activity')),
            body: RefreshIndicator(
              onRefresh: cubit.load,
              child: AsyncView(
                value: cubit.state,
                onRetry: cubit.load,
                builder: (records) {
                  final byEmployee = {for (final r in records) r.employeeId: r};
                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Text(
                          Clock.date(today),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      for (final person in reports) ...[
                        _ReportTile(person: person, record: byEmployee[person.id]),
                        const Divider(height: 1, indent: 76),
                      ],
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.person, required this.record});

  final Colleague person;
  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = this.record;
    final (label, tone) = person.onLeaveToday
        ? ('On leave', StatusTone.neutral)
        : record?.clockInAt == null
            ? ('Not clocked in', StatusTone.neutral)
            : record!.lateMinutes > 0
                ? ('Late ${Clock.duration(record.lateMinutes)}', StatusTone.warning)
                : ('On time', StatusTone.success);
    String time(DateTime? value) =>
        value == null ? '--:--' : Clock.hm(value, record?.timezone);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: InitialsAvatar(name: person.fullName, radius: 20),
      title: Text(person.fullName),
      subtitle: Text(
        record == null
            ? person.subtitle
            : 'In ${time(record.clockInAt)} · Out ${time(record.clockOutAt)}'
                '${record.isSuspicious ? ' · Flagged' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontFeatures: const [ui.FontFeature.tabularFigures()],
        ),
      ),
      trailing: StatusChip(label, tone: tone),
    );
  }
}
