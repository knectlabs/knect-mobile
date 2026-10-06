import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/clock_action_buttons.dart';
import '../../../shared/widgets/knect_feature_icon.dart';
import '../../../core/async/async_value.dart';
import '../../../core/brand/brand.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/initials_avatar.dart';
import '../../../shared/widgets/profile_photo_avatar.dart';
import '../../../shared/widgets/navigation.dart';
import '../../announcements/application/announcements_cubit.dart';
import '../../announcements/data/announcements_repository.dart';
import '../../announcements/presentation/announcement_detail_screen.dart';
import '../../announcements/presentation/announcements_screen.dart';
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

    // Default visible order (first seven are the direct shortcuts; the rest
    // live in All Apps once the eight-slot limit is exceeded).
    final apps = <_App>[
      _App(Icons.beach_access_outlined, 'Time Off',
          () => pushPage(context, const LeaveFormScreen())),
      _App(Icons.location_on_outlined, 'Live Attendance',
          () => pushPage(context, const AttendanceScreen())),
      _App(Icons.more_time_outlined, 'Overtime',
          () => pushPage(context, const OvertimeFormScreen())),
      _App(Icons.edit_calendar_outlined, 'Correction',
          () => pushPage(context, const CorrectionFormScreen())),
      _App(Icons.history_outlined, 'Attendance Log',
          () => pushPage(context, const AttendanceLogScreen())),
      _App(Icons.assignment_outlined, 'My Requests',
          () => context.go(AppRoutes.requests)),
      _App(Icons.receipt_long_outlined, 'Payslip',
          () => pushPage(context, const PayslipsScreen())),
      _App(Icons.account_balance_wallet_outlined, 'Reimbursement',
          () => pushPage(context, const ReimbursementsScreen())),
      _App(Icons.flag_outlined, 'My Goals',
          () => pushPage(context, const MyGoalsScreen())),
      _App(Icons.rate_review_outlined, 'My Reviews',
          () => pushPage(context, const MyReviewsScreen())),
      if (canApprove(user?.role))
        _App(Icons.fact_check_outlined, 'Approvals',
            () => pushPage(context, const ApprovalsScreen())),
    ];

    return BlocProvider(
      create: (context) =>
          AnnouncementsCubit(context.read<AnnouncementsRepository>()),
      child: Builder(
        builder: (context) {
          final unread = context.watch<UnreadCountCubit>().state;
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
                  context.read<AnnouncementsCubit>().load(),
                ]),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    Row(
                      children: [
                        ProfilePhotoAvatar(
                            name: name,
                            photoUrl: profile?.profilePhotoUrl,
                            radius: 22),
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
                        IconButton(
                          key: const Key('home.notifications'),
                          tooltip: 'Notifications',
                          onPressed: () {
                            context.read<UnreadCountCubit>().refresh();
                            context.go(AppRoutes.inbox);
                          },
                          icon: Badge(
                            isLabelVisible: unread > 0,
                            label: Text(unread > 99 ? '99+' : '$unread'),
                            child: const Icon(Icons.notifications_none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const _ShiftCard(),
                    const SizedBox(height: 16),
                    _AppGrid(apps: apps),
                    const SizedBox(height: 16),
                    const _AnnouncementsPreview(),
                    _DirectReports(myEmployeeId: profile?.id),
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

/* Shift schedule */

class _ShiftCard extends StatelessWidget {
  const _ShiftCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = context.watch<TodayCubit>().state;
    final today = state.valueOrPrevious;
    final tint = BrandColors.primaryViolet
        .withValues(alpha: theme.brightness == Brightness.dark ? 0.16 : 0.08);

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
  final ClockAction? next;

  @override
  Widget build(BuildContext context) => ClockActionButtons(
        keyPrefix: 'home',
        canClockIn: next == ClockAction.clockIn,
        canClockOut: next == ClockAction.clockOut,
        onClockIn: () => openClock(context, ClockAction.clockIn),
        onClockOut: () => openClock(context, ClockAction.clockOut),
      );
}

/* Apps */

class _App {
  const _App(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A single shortcut cell: a soft-lilac rounded container with a lilac icon and
/// a label. Uniform treatment — no per-shortcut colours.
class _AppTile extends StatelessWidget {
  const _AppTile(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: KnectFeatureIcon(icon: icon, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.apps});

  final List<_App> apps;

  @override
  Widget build(BuildContext context) {
    // Show at most 8 slots. If everything fits, show it all; otherwise show the
    // first 7 real shortcuts and make slot 8 "All Apps" (opens a bottom sheet
    // with the full grid).
    final overflow = apps.length > 8;
    final visible = overflow ? apps.take(7).toList() : apps;

    return Card(
      margin: EdgeInsets.zero,
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 18
            ? 3
            : 4,
        shrinkWrap: true,
        // Explicit padding; otherwise the grid inherits the status-bar inset.
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio:
            MediaQuery.textScalerOf(context).scale(14) > 18 ? 0.72 : 0.9,
        children: [
          for (final app in visible)
            KeyedSubtree(
              key: Key('home.app.${app.label}'),
              child: _AppTile(
                icon: app.icon,
                label: app.label,
                onTap: app.onTap,
              ),
            ),
          if (overflow)
            KeyedSubtree(
              key: const Key('home.app.All Apps'),
              child: _AppTile(
                icon: Icons.apps_outlined,
                label: 'All Apps',
                onTap: () => _showAllApps(context, apps),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllApps(BuildContext context, List<_App> apps) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'All apps',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio:
                      MediaQuery.textScalerOf(context).scale(14) > 18
                          ? 0.72
                          : 0.9,
                  children: [
                    for (final app in apps)
                      KeyedSubtree(
                        key: Key('home.allApps.${app.label}'),
                        child: _AppTile(
                          icon: app.icon,
                          label: app.label,
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            app.onTap();
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* Announcements */

/// Home preview of the latest published announcements: a section header with a
/// "View all" action and the latest two to three items, each a compact row with
/// subtle dividers. Backed by the Home-scoped [AnnouncementsCubit].
class _AnnouncementsPreview extends StatelessWidget {
  const _AnnouncementsPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    final state = context.watch<AnnouncementsCubit>().state;
    final announcements = state.valueOrPrevious;

    // Hide the whole section until we have something to show; errors and empty
    // states stay quiet on Home (the full list surfaces them).
    if (announcements == null || announcements.isEmpty) {
      return const SizedBox.shrink();
    }
    final latest = announcements.take(3).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Announcements',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  key: const Key('home.announcements.viewAll'),
                  onPressed: () =>
                      pushPage(context, const AnnouncementsScreen()),
                  child: const Text('View all'),
                ),
              ],
            ),
            for (var i = 0; i < latest.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _PreviewRow(announcement: latest[i], tz: tz),
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.announcement, required this.tz});

  final Announcement announcement;
  final String? tz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final author = announcement.authorName;
    final date = Clock.shortDate(Clock.toZone(announcement.displayDate, tz));
    final subtitle =
        author != null && author.isNotEmpty ? '$author · $date' : date;
    return InkWell(
      key: Key('home.announcement.${announcement.id}'),
      onTap: () => pushPage(
        context,
        AnnouncementDetailScreen(announcement: announcement),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialsAvatar(name: author ?? 'Announcement', radius: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
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
                        child: ProfilePhotoAvatar(
                            name: person.fullName,
                            photoUrl: person.profilePhotoUrl,
                            radius: 24),
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
