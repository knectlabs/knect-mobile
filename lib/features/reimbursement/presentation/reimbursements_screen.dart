import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../../payroll/presentation/payslip_format.dart';
import '../application/reimbursements_cubit.dart';
import '../data/reimbursement_repository.dart';
import 'reimbursement_form.dart';

/// Human label for a reimbursement category enum value (e.g. `OFFICE_SUPPLIES`
/// → `Office supplies`).
String reimbursementCategoryLabel(String category) {
  final words = category.toLowerCase().split('_');
  if (words.isEmpty) return category;
  final first = words.first;
  final capitalized =
      first.isEmpty ? first : '${first[0].toUpperCase()}${first.substring(1)}';
  return [capitalized, ...words.skip(1)].join(' ');
}

/// Employee reimbursement claims: own history plus a submission form. Approval
/// is handled by the generic approval engine, so there is no decision UI here.
class ReimbursementsScreen extends StatelessWidget {
  const ReimbursementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ReimbursementsCubit(context.read<ReimbursementRepository>()),
      child: const _ReimbursementsView(),
    );
  }
}

class _ReimbursementsView extends StatelessWidget {
  const _ReimbursementsView();

  Future<void> _new(BuildContext context) async {
    final submitted = await pushPage<bool>(
      context,
      BlocProvider.value(
        value: context.read<ReimbursementsCubit>(),
        child: const ReimbursementFormScreen(),
      ),
    );
    if (submitted == true && context.mounted) {
      await context.read<ReimbursementsCubit>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReimbursementsCubit>().state;
    final load = context.read<ReimbursementsCubit>().load;
    return Scaffold(
      appBar: AppBar(title: const Text('Reimbursement')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('reimbursement.new'),
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: const Text('New claim'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            AsyncView<List<ReimbursementClaim>>(
              value: state,
              onRetry: load,
              loading:
                  const SizedBox(height: 320, child: SkeletonList(count: 3)),
              builder: (claims) {
                if (claims.isEmpty) {
                  return const EmptyView(
                    icon: Icons.receipt_long_outlined,
                    title: 'No claims yet',
                    message:
                        'Submit an expense claim and track its approval here.',
                  );
                }
                return _ClaimList(claims: claims);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimList extends StatelessWidget {
  const _ClaimList({required this.claims});

  final List<ReimbursementClaim> claims;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, claim) in claims.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 16),
            ListTile(
              key: Key('reimbursement.item.${claim.id}'),
              title: Text(
                reimbursementCategoryLabel(claim.category),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_amount(claim)} · ${Clock.date(claim.expenseDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              trailing: StatusChip.approval(claim.status),
              onTap: () => _showDetail(context, claim),
            ),
          ],
        ],
      ),
    );
  }
}

String _amount(ReimbursementClaim claim) => claim.currency == 'IDR'
    ? formatIdr(claim.amount)
    : '${claim.currency} ${claim.amount}';

String? _tz(BuildContext context) =>
    context.read<AuthCubit>().state.user?.organization.timezone;

Future<void> _showDetail(BuildContext context, ReimbursementClaim claim) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => _ClaimDetail(
      claim: claim,
      timezone: _tz(context),
      cubit: context.read<ReimbursementsCubit>(),
      repository: context.read<ReimbursementRepository>(),
    ),
  );
}

class _ClaimDetail extends StatefulWidget {
  const _ClaimDetail({
    required this.claim,
    required this.timezone,
    required this.cubit,
    required this.repository,
  });

  final ReimbursementClaim claim;
  final String? timezone;
  final ReimbursementsCubit cubit;
  final ReimbursementRepository repository;

  @override
  State<_ClaimDetail> createState() => _ClaimDetailState();
}

class _ClaimDetailState extends State<_ClaimDetail> {
  bool _busy = false;

  Future<void> _cancel() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await widget.repository.cancel(widget.claim.id);
      await widget.cubit.load();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Claim cancelled.'),
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
    final claim = widget.claim;
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
                  child: Text(
                    reimbursementCategoryLabel(claim.category),
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                StatusChip.approval(claim.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_amount(claim)} · ${Clock.date(claim.expenseDate)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('Description', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(claim.description, style: theme.textTheme.bodyMedium),
            if (claim.receiptUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.attach_file,
                      size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Receipt attached',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (claim.decisionNote != null &&
                claim.decisionNote!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Decision note', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(claim.decisionNote!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text(
              'Submitted ${Clock.date(Clock.toZone(claim.submittedAt, widget.timezone))}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (claim.isPending) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('reimbursement.cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _busy ? null : _cancel,
                  child: Text(_busy ? 'Cancelling…' : 'Cancel claim'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
