import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../attendance/presentation/today_card.dart';
import '../../auth/application/auth_cubit.dart';
import '../../notifications/data/notifications_repository.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../requests/presentation/request_forms.dart';
import '../../shell/signed_in_scope.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.select((AuthCubit cubit) => cubit.state.user);
    final profile = context.watch<ProfileCubit>().state.valueOrPrevious;
    final name = profile?.firstName ?? user?.email.split('@').first;
    final timezone = user?.organization.timezone;
    final hour = Clock.toZone(DateTime.now(), timezone).hour;
    final greeting = hour < 11
        ? 'Good morning'
        : hour < 15
            ? 'Good afternoon'
            : hour < 19
                ? 'Good evening'
                : 'Good night';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            context.read<AuthCubit>().refreshProfile(),
            context.read<ProfileCubit>().load(),
            context.read<TodayCubit>().load(),
            context.read<UnreadCountCubit>().refresh(),
          ]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Row(
                children: [
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
                          name == null ? 'Welcome' : 'Hello, $name',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (user != null)
                          Text(
                            user.organization.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const NotificationBell(),
                ],
              ),
              const SizedBox(height: 20),
              const TodayCard(),
              const SizedBox(height: 28),
              Text('Requests', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
                children: [
                  _Action(
                    icon: Icons.beach_access_outlined,
                    label: 'Leave',
                    onTap: () => pushPage(context, const LeaveFormScreen()),
                  ),
                  _Action(
                    icon: Icons.more_time_outlined,
                    label: 'Overtime',
                    onTap: () => pushPage(context, const OvertimeFormScreen()),
                  ),
                  _Action(
                    icon: Icons.edit_calendar_outlined,
                    label: 'Correction',
                    onTap: () => pushPage(context, const CorrectionFormScreen()),
                  ),
                  if (canApprove(user?.role))
                    _Action(
                      icon: Icons.fact_check_outlined,
                      label: 'Approvals',
                      onTap: () => pushPage(context, const ApprovalsScreen()),
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

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bell with the unread count; opens the notification center.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UnreadCountCubit>().state;
    return IconButton(
      key: const Key('home.notifications'),
      tooltip: 'Notifications',
      onPressed: () async {
        final counter = context.read<UnreadCountCubit>();
        await pushPage(context, const NotificationsScreen());
        await counter.refresh();
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
