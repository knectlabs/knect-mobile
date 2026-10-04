import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../../shared/widgets/state_views.dart';
import '../../approvals/presentation/approvals_screen.dart';
import '../../auth/application/auth_cubit.dart';
import '../application/requests_cubit.dart';
import '../data/requests_repository.dart';
import 'request_forms.dart';

enum _Kind { leave, overtime, correction }

/// Requests tab: leave balances, own requests, and the approval inbox entry.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  _Kind _kind = _Kind.leave;

  Future<void> _new() async {
    final page = switch (_kind) {
      _Kind.leave => const LeaveFormScreen(),
      _Kind.overtime => const OvertimeFormScreen(),
      _Kind.correction => const CorrectionFormScreen(),
    };
    await pushPage<bool>(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<RequestsCubit>().state;
    final role = context.select((AuthCubit cubit) => cubit.state.user?.role);

    return Scaffold(
      appBar: AppBar(title: const Text('Requests')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('requests.new'),
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: Text(switch (_kind) {
          _Kind.leave => 'Request leave',
          _Kind.overtime => 'Request overtime',
          _Kind.correction => 'New correction',
        }),
      ),
      body: RefreshIndicator(
        onRefresh: context.read<RequestsCubit>().load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          children: [
            if (canApprove(role)) ...[
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(Icons.fact_check_outlined,
                      color: theme.colorScheme.primary),
                  title: const Text('Approval inbox'),
                  subtitle: const Text('Requests from your team'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => pushPage(context, const ApprovalsScreen()),
                ),
              ),
              const SizedBox(height: 16),
            ],
            SegmentedButton<_Kind>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Kind.leave, label: Text('Leave')),
                ButtonSegment(value: _Kind.overtime, label: Text('Overtime')),
                ButtonSegment(
                    value: _Kind.correction, label: Text('Correction')),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(height: 16),
            AsyncView(
              value: state,
              onRetry: context.read<RequestsCubit>().load,
              loading:
                  const SizedBox(height: 320, child: SkeletonList(count: 3)),
              builder: (overview) => switch (_kind) {
                _Kind.leave => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (overview.balances.isNotEmpty) ...[
                        _Balances(balances: overview.balances),
                        const SizedBox(height: 16),
                      ],
                      _RequestList(
                        requests: overview.leave,
                        empty: 'No leave requests yet',
                      ),
                    ],
                  ),
                _Kind.overtime => _RequestList(
                    requests: overview.overtime,
                    empty: 'No overtime requests yet',
                  ),
                _Kind.correction => _RequestList(
                    requests: overview.corrections,
                    empty: 'No corrections yet',
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Balances extends StatelessWidget {
  const _Balances({required this.balances});

  final List<LeaveBalance> balances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: balances.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final balance = balances[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  balance.leaveTypeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  leaveDays(balance.available),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  balance.pending > 0
                      ? '${leaveDays(balance.pending)} pending'
                      : 'available ${balance.year}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.empty});

  final List<EmployeeRequest> requests;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return EmptyView(
        icon: Icons.inbox_outlined,
        title: empty,
        message: 'Requests you submit and their approval status show here.',
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, request) in requests.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 16),
            ListTile(
              title: Text(_title(context, request)),
              subtitle: Text(
                _subtitle(context, request),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: StatusChip.approval(request.status),
              onTap: () => _showDetail(context, request),
            ),
          ],
        ],
      ),
    );
  }
}

String? _tz(BuildContext context) =>
    context.read<AuthCubit>().state.user?.organization.timezone;

String _title(BuildContext context, EmployeeRequest request) =>
    switch (request) {
      LeaveRequest r => r.leaveTypeName,
      OvertimeRequest r =>
        '${Clock.duration(r.approvedMinutes ?? r.requestedMinutes)} overtime',
      CorrectionRequest r => 'Correction · ${Clock.shortDate(r.date)}',
    };

String _subtitle(BuildContext context, EmployeeRequest request) {
  final tz = _tz(context);
  return switch (request) {
    LeaveRequest r => r.startDate == r.endDate
        ? '${Clock.date(r.startDate)} · ${leaveDays(r.requestedDays)}'
        : '${Clock.shortDate(r.startDate)} – ${Clock.shortDate(r.endDate)} · ${leaveDays(r.requestedDays)}',
    OvertimeRequest r =>
      '${Clock.date(r.date)} · ${Clock.hm(r.startAt, tz)}–${Clock.hm(r.endAt, tz)}',
    CorrectionRequest r => [
        if (r.clockInAt != null) 'In ${Clock.hm(r.clockInAt!, tz)}',
        if (r.clockOutAt != null) 'Out ${Clock.hm(r.clockOutAt!, tz)}',
      ].join(' · '),
  };
}

Future<void> _showDetail(BuildContext context, EmployeeRequest request) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _RequestDetail(
      request: request,
      title: _title(context, request),
      subtitle: _subtitle(context, request),
      requests: context.read<RequestsCubit>(),
      repository: context.read<RequestsRepository>(),
    ),
  );
}

class _RequestDetail extends StatefulWidget {
  const _RequestDetail({
    required this.request,
    required this.title,
    required this.subtitle,
    required this.requests,
    required this.repository,
  });

  final EmployeeRequest request;
  final String title;
  final String subtitle;
  final RequestsCubit requests;
  final RequestsRepository repository;

  @override
  State<_RequestDetail> createState() => _RequestDetailState();
}

class _RequestDetailState extends State<_RequestDetail> {
  bool _busy = false;

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(widget.request);
      await widget.requests.load();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Request cancelled.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMessage(context, failureMessage(apiFailureOf(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final request = widget.request;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child:
                        Text(widget.title, style: theme.textTheme.titleLarge)),
                StatusChip.approval(request.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text('Reason', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(request.reason, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
              'Submitted ${Clock.date(Clock.toZone(request.submittedAt, _tz(context)))}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (request.isPending) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('request.cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _busy ? null : _cancel,
                  child: Text(_busy ? 'Cancelling…' : 'Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
