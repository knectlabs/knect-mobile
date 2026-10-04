import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/time/format.dart';
import '../../../shared/widgets/navigation.dart';
import '../../../shared/widgets/state_views.dart';
import '../application/payslips_cubit.dart';
import '../data/payslip_repository.dart';
import 'payslip_detail_screen.dart';
import 'payslip_format.dart';

/// Read-only list of the employee's own payslips for finalized payroll periods
/// (PRD §5.13). Tapping a row opens the payslip detail.
class PayslipsScreen extends StatelessWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PayslipsCubit(context.read<PayslipRepository>()),
      child: const _PayslipsView(),
    );
  }
}

class _PayslipsView extends StatelessWidget {
  const _PayslipsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PayslipsCubit>().state;
    final load = context.read<PayslipsCubit>().load;
    return Scaffold(
      appBar: AppBar(title: const Text('Payslip')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            AsyncView<List<PayslipSummary>>(
              value: state,
              onRetry: load,
              loading:
                  const SizedBox(height: 320, child: SkeletonList(count: 3)),
              builder: (payslips) {
                if (payslips.isEmpty) {
                  return const EmptyView(
                    icon: Icons.receipt_long,
                    title: 'No payslips yet',
                    message:
                        'Payslips appear once HR finalizes a payroll period.',
                  );
                }
                return _PayslipList(payslips: payslips);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PayslipList extends StatelessWidget {
  const _PayslipList({required this.payslips});

  final List<PayslipSummary> payslips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, payslip) in payslips.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 16),
            ListTile(
              key: Key('payslip.item.${payslip.periodId}'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(
                payslip.periodName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Clock.shortDate(payslip.startDate)} – '
                      '${Clock.date(payslip.endDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gross ${formatIdr(payslip.grossSalary)} · '
                      'Deductions ${formatIdr(payslip.totalDeduction)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Net pay',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatIdr(payslip.netSalary),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              isThreeLine: true,
              onTap: () => pushPage(
                context,
                PayslipDetailScreen(
                  periodId: payslip.periodId,
                  periodName: payslip.periodName,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
