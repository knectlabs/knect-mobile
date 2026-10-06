import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../core/theme/knect_tokens.dart';
import '../../auth/application/auth_cubit.dart';
import '../application/reimbursements_cubit.dart';
import '../data/reimbursement_repository.dart';
import 'reimbursements_screen.dart';

/// The reimbursement category enum values, mirroring the API
/// `ReimbursementCategory`.
const _categories = <String>[
  'TRAVEL',
  'MEALS',
  'ACCOMMODATION',
  'TRANSPORT',
  'MEDICAL',
  'OFFICE_SUPPLIES',
  'TRAINING',
  'COMMUNICATION',
  'OTHER',
];

/// Submission form for a new reimbursement claim. The receipt attachment is
/// optional; if upload fails the employee can still submit without it.
class ReimbursementFormScreen extends StatefulWidget {
  const ReimbursementFormScreen({super.key});

  @override
  State<ReimbursementFormScreen> createState() =>
      _ReimbursementFormScreenState();
}

class _ReimbursementFormScreenState extends State<ReimbursementFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  DateTime? _date;
  String? _receiptUrl;
  bool _uploading = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _timezone(BuildContext context) =>
      context.read<AuthCubit>().state.user?.organization.timezone;

  num? get _parsedAmount {
    final value = num.tryParse(_amount.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  Future<void> _pickReceipt() async {
    final repository = context.read<ReimbursementRepository>();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await repository.uploadReceipt(picked.path);
      if (!mounted) return;
      setState(() {
        _receiptUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = failureMessage(apiFailureOf(error));
      });
    }
  }

  String? _validate() {
    if (_category == null) return 'Choose a category.';
    if (_parsedAmount == null) return 'Enter a valid amount.';
    if (_date == null) return 'Choose the expense date.';
    if (_description.text.trim().isEmpty) return 'Add a description.';
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final repository = context.read<ReimbursementRepository>();
    final cubit = context.read<ReimbursementsCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.submit(
        category: _category!,
        amount: _parsedAmount!,
        expenseDate: Clock.iso(_date!),
        description: _description.text.trim(),
        receiptUrl: _receiptUrl,
      );
      await cubit.load();
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(
        content: Text('Reimbursement claim submitted for approval.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failureMessage(apiFailureOf(error));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final today = Clock.today(_timezone(context));
    _date ??= today;
    return Scaffold(
      appBar: AppBar(title: const Text('New claim')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Card(
                margin: EdgeInsets.zero,
                child: Padding(
                    padding: KnectSpacing.page,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            key: const Key('reimbursement.category'),
                            initialValue: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                            items: [
                              for (final category in _categories)
                                DropdownMenuItem(
                                  value: category,
                                  child: Text(
                                      reimbursementCategoryLabel(category)),
                                ),
                            ],
                            onChanged: (value) =>
                                setState(() => _category = value),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('reimbursement.amount'),
                            controller: _amount,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              prefixIcon: Icon(Icons.payments_outlined),
                              prefixText: 'Rp ',
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _date!,
                                firstDate:
                                    today.subtract(const Duration(days: 365)),
                                lastDate: today,
                              );
                              if (picked != null) {
                                setState(() => _date = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Expense date',
                                prefixIcon: Icon(Icons.event_outlined),
                              ),
                              child: Text(Clock.date(_date!)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            key: const Key('reimbursement.description'),
                            controller: _description,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            key: const Key('reimbursement.receipt'),
                            onPressed: _uploading ? null : _pickReceipt,
                            icon: _uploading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Icon(_receiptUrl == null
                                    ? Icons.attach_file
                                    : Icons.check_circle_outline),
                            label: Text(_uploading
                                ? 'Uploading…'
                                : _receiptUrl == null
                                    ? 'Attach receipt (optional)'
                                    : 'Receipt attached'),
                          ),
                        ]))),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: TextStyle(color: colors.onErrorContainer)),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          key: const Key('reimbursement.submit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit claim'),
        ),
      ),
    );
  }
}
