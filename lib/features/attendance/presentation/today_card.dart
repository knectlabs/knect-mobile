import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/brand/brand.dart';
import '../../../core/time/format.dart';
import '../../shell/signed_in_scope.dart';
import '../data/attendance_repository.dart';
import 'clock_screen.dart';

/// Today's shift, clock times, and the next clock action.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TodayCubit>().state;
    final today = state.valueOrPrevious;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: BrandColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: today != null
            ? _TodayContent(today: today)
            : state is AsyncError<TodayStatus>
                ? _Unavailable(
                    message: failureMessage(state.failure),
                    onRetry: context.read<TodayCubit>().load,
                  )
                : const SizedBox(
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({required this.today});

  final TodayStatus today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final schedule = today.schedule;
    final record = today.record;
    final tz = schedule.timezone;
    const onBrand = Colors.white;
    final muted = onBrand.withValues(alpha: 0.72);

    String time(DateTime? value) => value == null ? '--:--' : Clock.hm(value, tz);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Clock.date(schedule.date).toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(
            color: muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          schedule.scheduled
              ? '${time(schedule.startsAt)} – ${time(schedule.endsAt)}'
              : 'No shift today',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: onBrand,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          schedule.scheduled
              ? [schedule.shiftName, schedule.officeName].whereType<String>().join(' · ')
              : 'Enjoy your day off.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        if (schedule.scheduled || record != null) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              _ClockStat(
                label: 'Clock in',
                value: time(record?.clockInAt),
                note: record != null && record.lateMinutes > 0
                    ? 'Late ${Clock.duration(record.lateMinutes)}'
                    : null,
              ),
              const SizedBox(width: 12),
              _ClockStat(
                label: 'Clock out',
                value: time(record?.clockOutAt),
                note: record?.workMinutes == null
                    ? null
                    : '${Clock.duration(record!.workMinutes!)} worked',
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ClockButton(today: today),
        ],
      ],
    );
  }
}

class _ClockStat extends StatelessWidget {
  const _ClockStat({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (note != null)
              Text(
                note!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: BrandColors.lightLilac,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClockButton extends StatelessWidget {
  const _ClockButton({required this.today});

  final TodayStatus today;

  @override
  Widget build(BuildContext context) {
    final tz = today.schedule.timezone;
    final pending = today.needsClockOut
        ? ClockAction.clockOut
        : today.needsClockIn
            ? ClockAction.clockIn
            : null;
    final window = today.window(DateTime.now());
    // Clock-out before its window is allowed (recorded as early leave);
    // after either window closes the API only accepts a correction.
    final blocked = window == WindowState.closed ||
        (pending == ClockAction.clockIn && window == WindowState.notOpen);
    final action = blocked ? null : pending;
    final opensAt = pending == ClockAction.clockOut
        ? today.schedule.clockOutOpensAt
        : today.schedule.clockInOpensAt;
    final label = switch (action) {
      ClockAction.clockIn => 'Clock in',
      ClockAction.clockOut => 'Clock out',
      null when pending == ClockAction.clockIn && window == WindowState.notOpen =>
        'Clock-in opens at ${Clock.hm(opensAt!, tz)}',
      null when pending == ClockAction.clockIn => 'Clock-in closed · request a correction',
      null when pending == ClockAction.clockOut => 'Clock-out closed · request a correction',
      null => today.done ? 'Done for today' : 'Nothing to record',
    };
    final style = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: BrandColors.deepViolet,
      disabledBackgroundColor: Colors.white.withValues(alpha: 0.18),
      disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
    );
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('today.clock'),
        style: style,
        onPressed: action == null ? null : () => openClock(context, action),
        icon: Icon(
          switch (action) {
            ClockAction.clockIn => Icons.login_rounded,
            ClockAction.clockOut => Icons.logout_rounded,
            null => Icons.check_circle_outline,
          },
        ),
        label: Text(label),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: Colors.white),
        const SizedBox(height: 8),
        Text(
          "Today's schedule could not load.",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        Text(
          message,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white54),
          ),
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}
