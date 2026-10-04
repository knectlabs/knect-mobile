import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/payslip_repository.dart';
import 'payslip_format.dart';

/// Read-only detail of one finalized payslip, loaded by payroll PERIOD id.
/// Mirrors RequestTargetScreen: loads a single item via a [FutureBuilder] with
/// error + retry. No actions — payslips are immutable snapshots.
class PayslipDetailScreen extends StatefulWidget {
  const PayslipDetailScreen({
    required this.periodId,
    required this.periodName,
    super.key,
  });

  final String periodId;
  final String periodName;

  @override
  State<PayslipDetailScreen> createState() => _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends State<PayslipDetailScreen> {
  late Future<Payslip> _payslip;

  @override
  void initState() {
    super.initState();
    _payslip = context.read<PayslipRepository>().detail(widget.periodId);
  }

  void _retry() => setState(() {
        _payslip = context.read<PayslipRepository>().detail(widget.periodId);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payslip')),
      body: FutureBuilder<Payslip>(
        future: _payslip,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(
              message: failureMessage(apiFailureOf(snapshot.error!)),
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _PayslipDetail(
            payslip: snapshot.data!,
            periodName: widget.periodName,
          );
        },
      ),
    );
  }
}

class _PayslipDetail extends StatelessWidget {
  const _PayslipDetail({required this.payslip, required this.periodName});

  final Payslip payslip;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earnings = payslip.earnings;
    final deductions = payslip.deductions;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        _Header(payslip: payslip, periodName: periodName),
        if (earnings.isNotEmpty) ...[
          const SizedBox(height: 20),
          _LineSection(title: 'Earnings', lines: earnings),
        ],
        if (deductions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _LineSection(title: 'Deductions', lines: deductions),
        ],
        const SizedBox(height: 16),
        _Totals(payslip: payslip),
        const SizedBox(height: 16),
        Text(
          payslip.employeeCode == null
              ? payslip.employeeName
              : '${payslip.employeeName} · ${payslip.employeeCode}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.payslip, required this.periodName});

  final Payslip payslip;
  final String periodName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    periodName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const StatusChip('Finalized', tone: StatusTone.success),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Net pay',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formatIdr(payslip.netSalary),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineSection extends StatelessWidget {
  const _LineSection({required this.title, required this.lines});

  final String title;
  final List<PayslipLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final (index, line) in lines.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 16),
                ListTile(
                  dense: true,
                  title: Text(line.name),
                  trailing: Text(
                    formatIdr(line.amount),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.payslip});

  final Payslip payslip;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            _TotalRow(label: 'Gross', amount: payslip.grossSalary),
            _TotalRow(label: 'Total deduction', amount: payslip.totalDeduction),
            if (isPositiveAmount(payslip.taxAmount))
              _TotalRow(label: 'Tax', amount: payslip.taxAmount),
            const Divider(height: 20),
            _TotalRow(
              label: 'Net pay',
              amount: payslip.netSalary,
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.emphasize = false,
  });

  final String label;
  final String amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = emphasize
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          );
    final valueStyle = emphasize
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          )
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(formatIdr(amount), style: valueStyle),
        ],
      ),
    );
  }
}
