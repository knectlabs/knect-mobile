import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/async/async_value.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../data/notifications_repository.dart';

class _NotificationsCubit extends LoadCubit<List<AppNotification>> {
  _NotificationsCubit(this._repository, this._unread) : super(_repository.list);

  final NotificationsRepository _repository;
  final UnreadCountCubit _unread;

  Future<void> markRead(AppNotification notification) async {
    if (!notification.unread) return;
    try {
      await _repository.markRead(notification.id);
    } catch (_) {}
    await Future.wait([load(), _unread.refresh()]);
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
    } catch (_) {}
    await Future.wait([load(), _unread.refresh()]);
  }
}

/// Notification list (Inbox tab): approval outcomes and requests awaiting a
/// decision.
class NotificationsList extends StatelessWidget {
  const NotificationsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _NotificationsCubit(
        context.read<NotificationsRepository>(),
        context.read<UnreadCountCubit>(),
      ),
      child: Builder(
        builder: (context) {
          final cubit = context.watch<_NotificationsCubit>();
          return RefreshIndicator(
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
                          message:
                              'Updates on your requests and approvals appear here.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: notifications.length + 1,
                      separatorBuilder: (_, index) => index == 0
                          ? const SizedBox.shrink()
                          : const Divider(height: 1, indent: 72),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final unread =
                              notifications.any((item) => item.unread);
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: TextButton(
                                onPressed: unread ? cubit.markAllRead : null,
                                child: const Text('Mark all read'),
                              ),
                            ),
                          );
                        }
                        return _NotificationTile(
                          notification: notifications[index - 1],
                          onOpen: (notification) =>
                              _openNotification(context, cubit, notification),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context,
    _NotificationsCubit cubit,
    AppNotification notification,
  ) async {
    await cubit.markRead(notification);
    if (!context.mounted || notification.target == null) return;

    if (notification.type == 'APPROVAL_REQUESTED') {
      await pushPage(context, const ApprovalsScreen());
      return;
    }
    context.go(AppRoutes.requests);
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onOpen});

  final AppNotification notification;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    final unread = notification.unread;
    final type = notification.type;
    final (icon, color) = type.contains('APPROVED')
        ? (Icons.check_circle, const Color(0xFF16A34A))
        : type.contains('REJECTED')
            ? (Icons.cancel, colors.error)
            : type.contains('APPROVAL')
                ? (Icons.pending_actions, const Color(0xFFF59E0B))
                : (Icons.notifications, colors.primary);
    return InkWell(
      onTap: () => onOpen(notification),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (notification.message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        notification.message,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${Clock.shortDate(Clock.toZone(notification.createdAt, tz))} · '
                    '${Clock.hm(notification.createdAt, tz)}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (unread)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 8),
                child: CircleAvatar(radius: 4, backgroundColor: colors.primary),
              ),
            Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
