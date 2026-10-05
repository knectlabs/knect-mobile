import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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
import '../../employee/data/directory_repository.dart';
import '../../employee/presentation/team_activity_screen.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../payroll/presentation/payslips_screen.dart';
import '../../performance/presentation/my_goals_screen.dart';
import '../../performance/presentation/my_reviews_screen.dart';
import '../../reimbursement/presentation/reimbursements_screen.dart';
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
    final hour = Clock.toZone(DateTime.now(), user?.organization.timezone).hour;
    final greeting = hour < 11
        ? 'Good morning,'
        : hour < 15
            ? 'Good afternoon,'
            : hour < 19
                ? 'Good evening,'
                : 'Good night,';

    final apps = <_App>[
      _App(Icons.beach_access, 'Time Off', const Color(0xFF2563EB),
          () => pushPage(context, const LeaveFormScreen())),
      _App(Icons.location_on, 'Live Attendance', const Color(0xFFEF4444),
          () => pushPage(context, const AttendanceScreen())),
      _App(Icons.more_time, 'Overtime', const Color(0xFFDB2777),
          () => pushPage(context, const OvertimeFormScreen())),
      _App(Icons.edit_calendar, 'Correction', const Color(0xFF0D9488),
          () => pushPage(context, const CorrectionFormScreen())),
      _App(Icons.history, 'Attendance Log', const Color(0xFFF97316),
          () => pushPage(context, const AttendanceLogScreen())),
      _App(Icons.assignment, 'My Requests', const Color(0xFF16A34A),
          () => context.go(AppRoutes.requests)),
      _App(Icons.receipt_long, 'Payslip', BrandColors.primaryViolet,
          () => pushPage(context, const PayslipsScreen())),
      _App(
          Icons.receipt_long_outlined,
          'Reimbursement',
          BrandColors.primaryViolet,
          () => pushPage(context, const ReimbursementsScreen())),
      _App(Icons.flag, 'My Goals', BrandColors.primaryViolet,
          () => pushPage(context, const MyGoalsScreen())),
      _App(Icons.rate_review, 'My Reviews', BrandColors.primaryViolet,
          () => pushPage(context, const MyReviewsScreen())),
      if (canApprove(user?.role))
        _App(Icons.fact_check, 'Approvals', BrandColors.primaryViolet,
            () => pushPage(context, const ApprovalsScreen())),
    ];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<AuthCubit>().refreshProfile(),
            context.read<ProfileCubit>().load(),
            context.read<TodayCubit>().load(),
            context.read<RequestsCubit>().load(),
            context.read<DirectoryCubit>().load(),
            context.read<UnreadCountCubit>().refresh(),
          ]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Row(
                children: [
                  InitialsAvatar(name: name, radius: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          name,
                          key: const Key('home.name'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _ShiftCard(),
              const SizedBox(height: 16),
              _AppGrid(apps: apps),
              _DirectReports(myEmployeeId: profile?.id),
            ],
          ),
        ),
      ),
    );
  }
}

/* Shift schedule */

class _ShiftCard extends StatelessWidget {
  const _ShiftCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = context.watch<TodayCubit>().state;
    final today = state.valueOrPrevious;
    final tint = BrandColors.primaryViolet.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08,
    );

    Widget body;
    var title = 'Shift schedule';
    if (today == null) {
      body = state is AsyncError<TodayStatus>
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    "Today's schedule could not load.\n${failureMessage(state.failure)}",
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: context.read<TodayCubit>().load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : const SizedBox(
              height: 150, child: Center(child: CircularProgressIndicator()));
    } else {
      final schedule = today.schedule;
      final tz = schedule.timezone;
      title = 'Shift schedule for ${Clock.date(schedule.date)}';
      final next = today.next(DateTime.now());
      final record = today.record;
      final utc = 'UTC+${Clock.offsetOf(tz).inHours}';
      final overnight = schedule.startsAt != null &&
          schedule.endsAt != null &&
          Clock.toZone(schedule.endsAt!, tz).day !=
              Clock.toZone(schedule.startsAt!, tz).day;
      final status = record?.clockOutAt != null
          ? 'You clocked out at ${Clock.hm(record!.clockOutAt!, tz)} ($utc)'
          : record?.clockInAt != null
              ? 'You have clocked in at ${Clock.hm(record!.clockInAt!, tz)} ($utc)'
              : next.action == null
                  ? next.label
                  : 'You have not clocked in yet';

      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          children: [
            if (!schedule.scheduled) ...[
              Text(
                'No shift today',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text('Enjoy your day off.', style: theme.textTheme.bodyMedium),
            ] else ...[
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    schedule.shiftName ?? 'Shift',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if ((schedule.office?.name ?? schedule.officeName) != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        schedule.office?.name ?? schedule.officeName!,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: '${Clock.hm(schedule.startsAt!, tz)} - '
                      '${Clock.hm(schedule.endsAt!, tz)}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontFeatures: const [ui.FontFeature.tabularFigures()],
                  ),
                  children: [
                    if (overnight)
                      TextSpan(
                          text: ' (+1d)', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ClockButtons(next: next.action),
              const SizedBox(height: 12),
              Text(status,
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: BrandColors.primaryViolet.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: BrandColors.secondaryViolet,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ColoredBox(color: tint, child: body),
          const Divider(height: 1),
          TextButton(
            key: const Key('home.liveAttendance'),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const RoundedRectangleBorder(),
              textStyle: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            onPressed: () => pushPage(context, const AttendanceScreen()),
            child: const Text('Open Live Attendance'),
          ),
        ],
      ),
    );
  }
}

class _ClockButtons extends StatelessWidget {
  const _ClockButtons({required this.next});

  /// The action available now; the other half is disabled.
  final ClockAction? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    Widget half(ClockAction action, IconData icon, String label, Color color) {
      final enabled = next == action;
      return Expanded(
        child: InkWell(
          key: Key('home.${action.name}'),
          onTap: enabled ? () => openClock(context, action) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Opacity(
              opacity: enabled ? 1 : 0.4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            half(ClockAction.clockIn, Icons.login_rounded, 'Clock In',
                BrandColors.secondaryViolet),
            VerticalDivider(
                width: 1,
                indent: 10,
                endIndent: 10,
                color: colors.outlineVariant),
            half(ClockAction.clockOut, Icons.logout_rounded, 'Clock Out',
                colors.error),
          ],
        ),
      ),
    );
  }
}

/* Apps */

class _App {
  const _App(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps});

  final List<_App> apps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        // Explicit padding; otherwise the grid inherits the status-bar inset.
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.9,
        children: [
          for (final app in apps)
            InkWell(
              key: Key('home.app.${app.label}'),
              borderRadius: BorderRadius.circular(12),
              onTap: app.onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [app.color.withValues(alpha: 0.75), app.color],
                      ),
                    ),
                    child: Icon(app.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* Direct reports */

class _DirectReports extends StatelessWidget {
  const _DirectReports({required this.myEmployeeId});

  final String? myEmployeeId;

  @override
  Widget build(BuildContext context) {
    final me = myEmployeeId;
    final people = context.watch<DirectoryCubit>().state.valueOrPrevious;
    if (me == null || people == null) return const SizedBox.shrink();
    final List<Colleague> reports =
        people.where((person) => person.managerId == me).toList();
    if (reports.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    const shown = 5;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'My direct reports',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    key: const Key('home.viewActivity'),
                    onPressed: () =>
                        pushPage(context, TeamActivityScreen(reports: reports)),
                    child: const Text('View activity'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final person in reports.take(shown))
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Tooltip(
                        message: person.fullName,
                        child:
                            InitialsAvatar(name: person.fullName, radius: 24),
                      ),
                    ),
                  if (reports.length > shown)
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        '+${reports.length - shown}',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
