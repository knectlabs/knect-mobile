import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../data/approvals_repository.dart';

class _InboxCubit extends LoadCubit<List<Approval>> {
  _InboxCubit(ApprovalsRepository repository, {required bool pending})
      : super(() => repository.inbox(pending: pending));
}

/// Approval history for managers and HR: pending decisions and decided ones.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _ApprovalsAppBar(),
        body: TabBarView(
          children: [ApprovalList(pending: true), ApprovalList(pending: false)],
        ),
      ),
    );
  }
}

class _ApprovalsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ApprovalsAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + kTextTabBarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        title: const Text('Approvals'),
        bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Decided')]),
      );
}

/// Approvals assigned to the signed-in user (pending or decided).
class ApprovalList extends StatelessWidget {
  const ApprovalList({required this.pending, super.key});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          _InboxCubit(context.read<ApprovalsRepository>(), pending: pending),
      child: _Inbox(pending: pending),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.pending});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<_InboxCubit>();
    final tz = context.select(
      (AuthCubit auth) => auth.state.user?.organization.timezone,
    );
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: AsyncView(
        value: cubit.state,
        onRetry: cubit.load,
        builder: (approvals) => approvals.isEmpty
            ? ListView(
                children: [
                  EmptyView(
                    icon: Icons.task_alt,
                    title: pending ? 'All caught up' : 'No decisions yet',
                    message: pending
                        ? 'New requests from your team will appear here.'
                        : 'Requests you approve or reject are listed here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: approvals.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) => _ApprovalTile(
                  approval: approvals[index],
                  timezone: tz,
                  trailing: pending ? null : StatusChip.approval(approvals[index].status),
                  onTap: pending ? () => _decide(context, approvals[index]) : null,
                ),
              ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, Approval approval) async {
    final cubit = context.read<_InboxCubit>();
    final decided = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _DecisionSheet(
        approval: approval,
        repository: context.read<ApprovalsRepository>(),
      ),
    );
    if (decided == true) await cubit.load();
  }
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({required this.approval, required this.repository});

  final Approval approval;
  final ApprovalsRepository repository;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _comment = TextEditingController();
  final _minutes = TextEditingController();
  bool? _busyApprove;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _submit(bool approve) async {
    final comment = _comment.text.trim();
    if (!approve && comment.isEmpty) {
      setState(() => _error = 'Add a comment so the employee knows why.');
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busyApprove = approve;
      _error = null;
    });
    try {
      await widget.repository.decide(
        widget.approval.id,
        approve: approve,
        comment: comment,
        approvedMinutes: approve ? int.tryParse(_minutes.text) : null,
      );
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(
        content: Text(approve ? 'Request approved.' : 'Request rejected.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (mounted) {
        setState(() {
          _busyApprove = null;
          _error = failureMessage(apiFailureOf(error));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approval = widget.approval;
    final busy = _busyApprove != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(approval.typeLabel.toUpperCase(), style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(approval.requesterName, style: theme.textTheme.titleLarge),
            if (approval.title != null) Text(approval.title!, style: theme.textTheme.bodyLarge),
            if (approval.subtitle != null)
              Text(
                approval.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            if (approval.isOvertime) ...[
              TextField(
                controller: _minutes,
                enabled: !busy,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Approved minutes (optional)',
                  helperText: 'Leave empty to approve the requested time.',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const Key('approval.comment'),
              controller: _comment,
              enabled: !busy,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comment',
                helperText: 'Required when rejecting.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('approval.reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: busy ? null : () => _submit(false),
                    child: Text(_busyApprove == false ? 'Rejecting…' : 'Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('approval.approve'),
                    onPressed: busy ? null : () => _submit(true),
                    child: Text(_busyApprove == true ? 'Approving…' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ApprovalTile extends StatelessWidget {
  const _ApprovalTile({
    required this.approval,
    required this.timezone,
    this.trailing,
    this.onTap,
  });

  final Approval approval;
  final String? timezone;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final (icon, color) = switch (approval.targetType) {
      'LEAVE_REQUEST' => (Icons.beach_access, const Color(0xFF2563EB)),
      'OVERTIME_REQUEST' => (Icons.more_time, const Color(0xFFEA580C)),
      _ => (Icons.edit_calendar, const Color(0xFF0D9488)),
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(approval.requesterName, style: theme.textTheme.titleSmall),
                  Text(
                    [approval.title ?? approval.typeLabel, if (approval.subtitle != null) approval.subtitle!]
                        .join(' · '),
                    style: muted,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${approval.typeLabel} · ${Clock.date(Clock.toZone(approval.createdAt, timezone))}',
                    style: muted,
                  ),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
