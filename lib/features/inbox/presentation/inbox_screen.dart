import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/widgets/large_title.dart';
import '../../../core/theme/knect_tokens.dart';
import '../../../shared/widgets/navigation.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../auth/application/auth_cubit.dart';
import '../../notifications/presentation/notifications_screen.dart';

/// Inbox tab: notifications, plus requests awaiting the user's decision for
/// managers and HR.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final approver = canApprove(
      context.select((AuthCubit cubit) => cubit.state.user?.role),
    );
    final theme = Theme.of(context);

    if (!approver) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LargeTitle('Inbox'),
              Expanded(child: NotificationsList()),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LargeTitle(
                'Inbox',
                action: IconButton(
                  tooltip: 'Approval history',
                  onPressed: () => pushPage(context, const ApprovalsScreen()),
                  icon: const Icon(Icons.history),
                ),
              ),
              ColoredBox(
                color: KnectColors.surface,
                child: TabBar(
                  labelStyle: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Notifications'),
                    Tab(text: 'Need My Approval'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [NotificationsList(), ApprovalList(pending: true)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
