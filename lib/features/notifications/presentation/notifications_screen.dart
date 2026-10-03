import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../data/notifications_repository.dart';

class _NotificationsCubit extends LoadCubit<List<AppNotification>> {
  _NotificationsCubit(this._repository) : super(_repository.list);

  final NotificationsRepository _repository;

  Future<void> markRead(AppNotification notification) async {
    if (!notification.unread) return;
    try {
      await _repository.markRead(notification.id);
    } catch (_) {}
    await load();
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
    } catch (_) {}
    await load();
  }
}

/// Notification center: approval outcomes and requests awaiting a decision.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _NotificationsCubit(context.read<NotificationsRepository>()),
      child: Builder(
        builder: (context) {
          final cubit = context.watch<_NotificationsCubit>();
          final items = cubit.state.valueOrPrevious ?? const [];
          return Scaffold(
            appBar: AppBar(
              title: const Text('Notifications'),
              actions: [
                if (items.any((item) => item.unread))
                  TextButton(
                    onPressed: cubit.markAllRead,
                    child: const Text('Mark all read'),
                  ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: cubit.load,
              child: AsyncView(
                value: cubit.state,
                onRetry: cubit.load,
                builder: (notifications) => notifications.isEmpty
                    ? ListView(
                        children: const [
                          EmptyView(
                            icon: Icons.notifications_none,
                            title: 'No notifications',
                            message: 'Updates on your requests and approvals appear here.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) =>
                            _NotificationTile(notification: notifications[index]),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    final local = Clock.toZone(notification.createdAt, tz);
    final unread = notification.unread;
    final icon = switch (notification.type) {
      final type when type.contains('APPROVED') => Icons.check_circle_outline,
      final type when type.contains('REJECTED') => Icons.cancel_outlined,
      final type when type.contains('APPROVAL') => Icons.fact_check_outlined,
      _ => Icons.notifications_outlined,
    };
    return Material(
      color: unread ? colors.primaryContainer.withValues(alpha: 0.25) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
        ),
        title: Text(
          notification.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${notification.message}\n'
          '${Clock.shortDate(local)} · ${Clock.hm(notification.createdAt, tz)}',
        ),
        isThreeLine: true,
        trailing: unread
            ? CircleAvatar(radius: 4, backgroundColor: colors.primary)
            : null,
        onTap: () => context.read<_NotificationsCubit>().markRead(notification),
      ),
    );
  }
}
