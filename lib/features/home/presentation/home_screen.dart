import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async/async_value.dart';
import '../../../core/brand/brand.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/navigation.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/presentation/attendance_screen.dart';
import '../../attendance/presentation/clock_screen.dart';
import '../../auth/application/auth_cubit.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../requests/application/requests_cubit.dart';
import '../../requests/presentation/request_forms.dart';
import '../../shell/signed_in_scope.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final profile = context.watch<ProfileCubit>().state.valueOrPrevious;
    final name = profile?.fullName ?? user?.email.split('@').first ?? 'Welcome';
    final role = [profile?.position?.name, profile?.department?.name]
        .whereType<String>()
        .join(' · ');
    final topInset = MediaQuery.paddingOf(context).top;

    final menu = <_MenuItem>[
      _MenuItem(Icons.fingerprint, 'Attendance', const Color(0xFFF59E0B),
          () => context.go(AppRoutes.attendance)),
      _MenuItem(Icons.beach_access, 'Time Off', const Color(0xFF2563EB),
          () => pushPage(context, const LeaveFormScreen())),
      _MenuItem(Icons.more_time, 'Overtime', const Color(0xFFEA580C),
          () => pushPage(context, const OvertimeFormScreen())),
      _MenuItem(Icons.edit_calendar, 'Correction', const Color(0xFF0D9488),
          () => pushPage(context, const CorrectionFormScreen())),
      _MenuItem(Icons.history, 'Attendance Log', const Color(0xFF7C3AED),
          () => pushPage(context, const AttendanceLogScreen())),
      _MenuItem(Icons.assignment, 'My Requests', const Color(0xFF16A34A),
          () => context.go(AppRoutes.requests)),
      if (canApprove(user?.role))
        _MenuItem(Icons.fact_check, 'Approvals', const Color(0xFFDB2777),
            () => pushPage(context, const ApprovalsScreen())),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<AuthCubit>().refreshProfile(),
            context.read<ProfileCubit>().load(),
            context.read<TodayCubit>().load(),
            context.read<RequestsCubit>().load(),
            context.read<UnreadCountCubit>().refresh(),
          ]),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  Container(
                    height: topInset + 300,
                    decoration: const BoxDecoration(gradient: BrandColors.brandGradient),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, topInset + 28, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (user != null)
                                      Text(
                                        user.organization.name,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.8),
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      name,
                                      key: const Key('home.name'),
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      role.isEmpty ? (user?.role.label ?? '') : role,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: Colors.white.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InitialsAvatar(name: name, radius: 30, onBrand: true),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _MenuCard(items: menu),
                        const SizedBox(height: 16),
                        const _QuickRequests(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.attendance),
                      child: const Text('Live Attendance'),
                    ),
                  ],
                ),
              ),
              const _TodaySummary(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          // Without this the grid inherits the status-bar inset as padding.
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.95,
          children: [
            for (final item in items)
              InkWell(
                key: Key('home.menu.${item.label}'),
                borderRadius: BorderRadius.circular(12),
                onTap: item.onTap,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(item.icon, color: item.color, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickRequests extends StatelessWidget {
  const _QuickRequests();

  @override
  Widget build(BuildContext context) {
    final entries = [
      (Icons.event_available_outlined, 'Time Off', const LeaveFormScreen()),
      (Icons.schedule_outlined, 'Overtime', const OvertimeFormScreen()),
      (Icons.edit_calendar_outlined, 'Correction', const CorrectionFormScreen()),
    ];
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final (icon, label, page) = entries[index];
          return Material(
            color: theme.colorScheme.surfaceContainerLowest,
            elevation: 2,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => pushPage(context, page),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(label, style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Today's shift and clock times with the next action.
class _TodaySummary extends StatelessWidget {
  const _TodaySummary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<TodayCubit>().state;
    final today = state.valueOrPrevious;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Widget content;
    if (today == null) {
      content = state is AsyncError<TodayStatus>
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    "Today's schedule could not load. "
                    '${failureMessage(state.failure)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: context.read<TodayCubit>().load,
                  child: const Text('Retry'),
                ),
              ],
            )
          : const SizedBox(height: 72, child: Center(child: CircularProgressIndicator()));
    } else {
      final schedule = today.schedule;
      final record = today.record;
      final tz = schedule.timezone;
      final next = today.next(DateTime.now());
      String time(DateTime? value) => value == null ? '--:--' : Clock.hm(value, tz);
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule.scheduled ? (schedule.shiftName ?? 'Shift') : 'No shift today',
            style: muted,
          ),
          const SizedBox(height: 2),
          Text(
            schedule.scheduled
                ? '${time(schedule.startsAt)} - ${time(schedule.endsAt)}'
                : 'Enjoy your day off',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [ui.FontFeature.tabularFigures()],
            ),
          ),
          if (schedule.scheduled || record != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _Stamp(label: 'Clock in', value: time(record?.clockInAt),
                    late: (record?.lateMinutes ?? 0) > 0),
                const SizedBox(width: 24),
                _Stamp(label: 'Clock out', value: time(record?.clockOutAt)),
                const Spacer(),
                FilledButton(
                  key: const Key('today.clock'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: next.action == null
                      ? null
                      : () => openClock(context, next.action!),
                  child: Text(switch (next.action) {
                    ClockAction.clockIn => 'Clock in',
                    ClockAction.clockOut => 'Clock out',
                    null => today.done
                        ? 'Done'
                        : today.needsClockOut
                            ? 'Clock out'
                            : 'Clock in',
                  }),
                ),
              ],
            ),
            if (next.action == null && !today.done) ...[
              const SizedBox(height: 8),
              Text(next.label, style: muted),
            ],
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(16), child: content),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.label, required this.value, this.late = false});

  final String label;
  final String value;
  final bool late;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: late ? theme.colorScheme.error : null,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
