import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/brand/brand.dart';
import '../../../core/geo/distance.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../../shell/signed_in_scope.dart';
import '../data/attendance_repository.dart';
import 'clock_screen.dart';

/// Attendance tab ("Live Attendance"): live clock, today's schedule, clock
/// buttons, and today's log.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodayCubit>().state;
    final today = state.valueOrPrevious;
    final timezone = today?.schedule.timezone ??
        context.select((AuthCubit auth) => auth.state.user?.organization.timezone);
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: context.read<TodayCubit>().load,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  // Header extends behind the top of the schedule card.
                  Container(
                    height: 290 + MediaQuery.paddingOf(context).top,
                    decoration: const BoxDecoration(gradient: BrandColors.brandGradient),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Live Attendance',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _LiveClock(timezone: timezone),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _ScheduleCard(state: state),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Attendance log', style: theme.textTheme.titleMedium),
                    ),
                    TextButton(
                      key: const Key('attendance.viewLog'),
                      onPressed: () => pushPage(context, const AttendanceLogScreen()),
                      child: const Text('View log'),
                    ),
                  ],
                ),
              ),
              _TodayLog(record: today?.record),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.timezone});

  final String? timezone;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = Clock.toZone(_now, widget.timezone);
    return Column(
      children: [
        Text(
          Clock.hm(_now, widget.timezone),
          style: theme.textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          Clock.date(local),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.state});

  final AsyncValue<TodayStatus> state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = state.valueOrPrevious;
    Widget body;
    if (today == null) {
      body = state is AsyncError<TodayStatus>
          ? Column(
              children: [
                Text(
                  "Today's schedule could not load.\n"
                  '${failureMessage((state as AsyncError<TodayStatus>).failure)}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: context.read<TodayCubit>().load,
                  child: const Text('Try again'),
                ),
              ],
            )
          : const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    } else {
      final schedule = today.schedule;
      final tz = schedule.timezone;
      final next = today.next(DateTime.now());
      final muted = theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      );
      body = Column(
        children: [
          Text('Schedule: ${Clock.date(schedule.date)}', style: muted),
          const SizedBox(height: 6),
          if (schedule.scheduled) ...[
            Text(
              schedule.shiftName ?? 'Shift',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              '${Clock.hm(schedule.startsAt!, tz)} - ${Clock.hm(schedule.endsAt!, tz)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
            if (schedule.office != null)
              Text(
                '${schedule.office!.name} · radius ${formatDistance(schedule.office!.radiusMeters)}',
                style: muted,
              ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selfie is required to clock in and clock out',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    key: const Key('attendance.clockIn'),
                    onPressed: next.action == ClockAction.clockIn
                        ? () => openClock(context, ClockAction.clockIn)
                        : null,
                    child: const Text('Clock in'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('attendance.clockOut'),
                    onPressed: next.action == ClockAction.clockOut
                        ? () => openClock(context, ClockAction.clockOut)
                        : null,
                    child: const Text('Clock out'),
                  ),
                ),
              ],
            ),
            if (next.action == null) ...[
              const SizedBox(height: 10),
              Text(next.label, style: muted, textAlign: TextAlign.center),
            ],
          ] else ...[
            Text(
              'No shift today',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text('Enjoy your day off.', style: muted),
          ],
        ],
      );
    }
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(padding: const EdgeInsets.all(18), child: body),
    );
  }
}

class _TodayLog extends StatelessWidget {
  const _TodayLog({required this.record});

  final AttendanceRecord? record;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    if (record == null || record.clockInAt == null) {
      return const EmptyView(
        icon: Icons.history_toggle_off,
        title: 'No activity log today',
        message: 'Your clock in/clock out activity will appear here.',
      );
    }
    final tz = record.timezone;
    // Newest first.
    final rows = [
      if (record.clockOutAt != null)
        _LogRow(
          time: Clock.hm(record.clockOutAt!, tz),
          event: 'Clock Out',
          detail: [
            if (record.workMinutes != null)
              '${Clock.duration(record.workMinutes!)} worked',
            if (record.earlyLeaveMinutes > 0)
              'Left ${Clock.duration(record.earlyLeaveMinutes)} early',
            if (record.clockOutLocationValid == false) 'Outside office area',
          ].join(' · '),
          flagged: record.earlyLeaveMinutes > 0 ||
              record.clockOutLocationValid == false,
        ),
      _LogRow(
        time: Clock.hm(record.clockInAt!, tz),
        event: 'Clock In',
        detail: [
          if (record.lateMinutes > 0) 'Late ${Clock.duration(record.lateMinutes)}',
          if (record.clockInDistanceM != null)
            '${formatDistance(record.clockInDistanceM!)} from office',
        ].join(' · '),
        flagged: record.lateMinutes > 0,
      ),
    ];
    return Column(
      children: [
        for (final row in rows) ...[
          row,
          const Divider(height: 1, indent: 20, endIndent: 20),
        ],
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.time,
    required this.event,
    required this.detail,
    this.flagged = false,
  });

  final String time;
  final String event;
  final String detail;

  /// Late, early leave, or outside the area: the time is shown in red.
  final bool flagged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              time,
              style: theme.textTheme.titleMedium?.copyWith(
                color: flagged ? theme.colorScheme.error : null,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event, style: theme.textTheme.titleMedium),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* Full log */

class _HistoryCubit extends LoadCubit<List<AttendanceRecord>> {
  _HistoryCubit(AttendanceRepository repository) : super(repository.history);
}

/// Attendance history (last 31 records).
class AttendanceLogScreen extends StatelessWidget {
  const AttendanceLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _HistoryCubit(context.read<AttendanceRepository>()),
      child: Builder(
        builder: (context) {
          final cubit = context.watch<_HistoryCubit>();
          return Scaffold(
            appBar: AppBar(title: const Text('Attendance log')),
            body: RefreshIndicator(
              onRefresh: cubit.load,
              child: AsyncView(
                value: cubit.state,
                onRetry: cubit.load,
                builder: (records) => records.isEmpty
                    ? ListView(
                        children: const [
                          EmptyView(
                            icon: Icons.event_available_outlined,
                            title: 'No attendance yet',
                            message: 'Your clock-ins will appear here.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: records.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                        itemBuilder: (_, index) => _HistoryTile(record: records[index]),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String time(DateTime? value) =>
        value == null ? '--:--' : Clock.hm(value, record.timezone);
    final (label, tone) = switch (record.status) {
      'PRESENT' => ('Present', StatusTone.success),
      'LATE' => ('Late ${Clock.duration(record.lateMinutes)}', StatusTone.warning),
      'ABSENT' => ('Absent', StatusTone.danger),
      'LEAVE' => ('Leave', StatusTone.neutral),
      'SICK' => ('Sick', StatusTone.neutral),
      'OFF_DAY' => ('Off day', StatusTone.neutral),
      'HOLIDAY' => ('Holiday', StatusTone.neutral),
      final other => (other, StatusTone.neutral),
    };
    return ListTile(
      title: Text(Clock.date(record.date)),
      subtitle: Text(
        '${time(record.clockInAt)} – ${time(record.clockOutAt)}'
        '${record.workMinutes == null ? '' : ' · ${Clock.duration(record.workMinutes!)}'}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: const [ui.FontFeature.tabularFigures()],
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusChip(label, tone: tone),
          if (record.isSuspicious)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Under review',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.tertiary),
              ),
            ),
        ],
      ),
    );
  }
}
