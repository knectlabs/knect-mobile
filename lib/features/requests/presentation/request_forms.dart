import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../application/requests_cubit.dart';
import '../data/requests_repository.dart';

String? _timezoneOf(BuildContext context) =>
    context.read<AuthCubit>().state.user?.organization.timezone;

String _hhmm(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// Shared layout: fields, inline error, and a pinned submit button.
class _RequestForm extends StatefulWidget {
  const _RequestForm({
    required this.title,
    required this.submitLabel,
    required this.successMessage,
    required this.fields,
    required this.validate,
    required this.submit,
  });

  final String title;
  final String submitLabel;
  final String successMessage;
  final List<Widget> fields;

  /// Returns a message when the form cannot be sent yet.
  final String? Function() validate;
  final Future<void> Function(RequestsRepository repository) submit;

  @override
  State<_RequestForm> createState() => _RequestFormState();
}

class _RequestFormState extends State<_RequestForm> {
  bool _busy = false;
  String? _error;

  Future<void> _send() async {
    final problem = widget.validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final repository = context.read<RequestsRepository>();
    final requests = context.read<RequestsCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(repository);
      requests.load();
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text(widget.successMessage), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = failureMessage(apiFailureOf(error));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final field in widget.fields) ...[field, const SizedBox(height: 14)],
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: TextStyle(color: colors.onErrorContainer)),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: FilledButton(
          key: const Key('request.submit'),
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ),
    );
  }
}

/// Read-only field that opens a picker.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: value != null && onClear != null
              ? IconButton(onPressed: onClear, icon: const Icon(Icons.close))
              : null,
        ),
        isEmpty: value == null,
        child: value == null ? null : Text(value!),
      ),
    );
  }
}

class _ReasonField extends StatelessWidget {
  const _ReasonField(this.controller);

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('request.reason'),
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Reason',
          alignLabelWithHint: true,
        ),
      );
}

Future<DateTime?> _pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) =>
    showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
    );

/* Leave */

class LeaveFormScreen extends StatefulWidget {
  const LeaveFormScreen({super.key});

  @override
  State<LeaveFormScreen> createState() => _LeaveFormScreenState();
}

class _LeaveTypesCubit extends LoadCubit<List<LeaveType>> {
  _LeaveTypesCubit(RequestsRepository repository) : super(repository.leaveTypes);
}

class _LeaveFormScreenState extends State<LeaveFormScreen> {
  final _reason = TextEditingController();
  LeaveType? _type;
  DateTime? _start;
  DateTime? _end;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = Clock.today(_timezoneOf(context));
    final balances =
        context.watch<RequestsCubit>().state.valueOrPrevious?.balances ?? const [];
    final balance = balances.where((b) => b.leaveTypeId == _type?.id).firstOrNull;

    return BlocProvider(
      create: (context) => _LeaveTypesCubit(context.read<RequestsRepository>()),
      child: Builder(
        builder: (context) {
          final types = context.watch<_LeaveTypesCubit>().state;
          return _RequestForm(
            title: 'Request leave',
            submitLabel: 'Submit request',
            successMessage: 'Leave request submitted for approval.',
            validate: () {
              if (_type == null) return 'Choose a leave type.';
              if (_start == null || _end == null) return 'Choose the start and end dates.';
              if (_reason.text.trim().isEmpty) return 'Add a reason.';
              return null;
            },
            submit: (repository) => repository.submitLeave(
              leaveTypeId: _type!.id,
              startDate: Clock.iso(_start!),
              endDate: Clock.iso(_end!),
              reason: _reason.text.trim(),
            ),
            fields: [
              switch (types) {
                AsyncData(:final value) => DropdownButtonFormField<LeaveType>(
                    key: const Key('leave.type'),
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      for (final type in value)
                        DropdownMenuItem(value: type, child: Text(type.name)),
                    ],
                    onChanged: (type) => setState(() => _type = type),
                  ),
                AsyncError(:final failure) => ErrorView(
                    message: failureMessage(failure),
                    onRetry: context.read<_LeaveTypesCubit>().load,
                  ),
                _ => const LinearProgressIndicator(),
              },
              if (_type != null)
                Text(
                  [
                    if (balance != null)
                      '${leaveDays(balance.available)} available'
                          '${balance.pending > 0 ? ' · ${leaveDays(balance.pending)} pending' : ''}',
                    if (_type!.minimumNoticeDays > 0)
                      'Request at least ${_type!.minimumNoticeDays} days ahead',
                    if (!_type!.paid) 'Unpaid',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              _PickerField(
                label: 'Start date',
                icon: Icons.event_outlined,
                value: _start == null ? null : Clock.date(_start!),
                onTap: () async {
                  final picked = await _pickDate(
                    context,
                    initial: _start ?? today.add(const Duration(days: 1)),
                    first: today.subtract(const Duration(days: 30)),
                    last: today.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _start = picked;
                      if (_end == null || _end!.isBefore(picked)) _end = picked;
                    });
                  }
                },
              ),
              _PickerField(
                label: 'End date',
                icon: Icons.event_outlined,
                value: _end == null ? null : Clock.date(_end!),
                onTap: () async {
                  final first = _start ?? today.subtract(const Duration(days: 30));
                  final picked = await _pickDate(
                    context,
                    initial: _end ?? first,
                    first: first,
                    last: today.add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _end = picked);
                },
              ),
              _ReasonField(_reason),
            ],
          );
        },
      ),
    );
  }
}

/// "1 day", "2.5 days".
String leaveDays(double value) {
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return '$text ${value == 1 ? 'day' : 'days'}';
}

/* Overtime */

class OvertimeFormScreen extends StatefulWidget {
  const OvertimeFormScreen({super.key});

  @override
  State<OvertimeFormScreen> createState() => _OvertimeFormScreenState();
}

class _OvertimeFormScreenState extends State<OvertimeFormScreen> {
  final _reason = TextEditingController();
  DateTime? _date;
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  int? get _minutes {
    if (_start == null || _end == null) return null;
    var minutes = (_end!.hour * 60 + _end!.minute) - (_start!.hour * 60 + _start!.minute);
    if (minutes <= 0) minutes += 24 * 60;
    return minutes;
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (start ? _start : _end) ??
          (start ? const TimeOfDay(hour: 17, minute: 0) : const TimeOfDay(hour: 19, minute: 0)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final today = Clock.today(_timezoneOf(context));
    _date ??= today;
    final minutes = _minutes;
    return _RequestForm(
      title: 'Request overtime',
      submitLabel: 'Submit request',
      successMessage: 'Overtime request submitted for approval.',
      validate: () {
        if (_start == null || _end == null) return 'Choose the start and end time.';
        if (_reason.text.trim().isEmpty) return 'Add a reason.';
        return null;
      },
      submit: (repository) => repository.submitOvertime(
        date: Clock.iso(_date!),
        startTime: _hhmm(_start!),
        endTime: _hhmm(_end!),
        reason: _reason.text.trim(),
      ),
      fields: [
        _PickerField(
          label: 'Date',
          icon: Icons.event_outlined,
          value: Clock.date(_date!),
          onTap: () async {
            final picked = await _pickDate(
              context,
              initial: _date!,
              first: today.subtract(const Duration(days: 31)),
              last: today.add(const Duration(days: 31)),
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        Row(
          children: [
            Expanded(
              child: _PickerField(
                label: 'Start',
                icon: Icons.schedule_outlined,
                value: _start == null ? null : _hhmm(_start!),
                onTap: () => _pickTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PickerField(
                label: 'End',
                icon: Icons.schedule_outlined,
                value: _end == null ? null : _hhmm(_end!),
                onTap: () => _pickTime(false),
              ),
            ),
          ],
        ),
        if (minutes != null)
          Text(
            '${Clock.duration(minutes)} of overtime'
            '${_end!.hour * 60 + _end!.minute <= _start!.hour * 60 + _start!.minute ? ' (ends the next day)' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        _ReasonField(_reason),
      ],
    );
  }
}

/* Attendance correction */

class CorrectionFormScreen extends StatefulWidget {
  const CorrectionFormScreen({this.date, super.key});

  /// Prefills the date (e.g. from an attendance history row).
  final DateTime? date;

  @override
  State<CorrectionFormScreen> createState() => _CorrectionFormScreenState();
}

class _CorrectionFormScreenState extends State<CorrectionFormScreen> {
  final _reason = TextEditingController();
  late DateTime? _date = widget.date;
  TimeOfDay? _in;
  TimeOfDay? _out;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool clockIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (clockIn ? _in : _out) ??
          (clockIn ? const TimeOfDay(hour: 8, minute: 0) : const TimeOfDay(hour: 17, minute: 0)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => clockIn ? _in = picked : _out = picked);
  }

  @override
  Widget build(BuildContext context) {
    final timezone = _timezoneOf(context);
    final today = Clock.today(timezone);
    _date ??= today;

    DateTime? instant(TimeOfDay? time, {bool nextDay = false}) => time == null
        ? null
        : Clock.fromZone(
            _date!.add(Duration(days: nextDay ? 1 : 0)),
            time.hour,
            time.minute,
            timezone,
          );

    return _RequestForm(
      title: 'Correct attendance',
      submitLabel: 'Submit correction',
      successMessage: 'Correction submitted for approval.',
      validate: () {
        if (_in == null && _out == null) return 'Enter the clock-in time, clock-out time, or both.';
        if (_reason.text.trim().isEmpty) return 'Explain what happened.';
        return null;
      },
      submit: (repository) {
        final overnight = _in != null &&
            _out != null &&
            _out!.hour * 60 + _out!.minute <= _in!.hour * 60 + _in!.minute;
        return repository.submitCorrection(
          date: Clock.iso(_date!),
          clockInAt: instant(_in),
          clockOutAt: instant(_out, nextDay: overnight),
          reason: _reason.text.trim(),
        );
      },
      fields: [
        Text(
          'Use this when you forgot to clock in or out, or a time was recorded wrong.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        _PickerField(
          label: 'Date',
          icon: Icons.event_outlined,
          value: Clock.date(_date!),
          onTap: () async {
            final picked = await _pickDate(
              context,
              initial: _date!,
              first: today.subtract(const Duration(days: 31)),
              last: today,
            );
            if (picked != null) setState(() => _date = picked);
          },
        ),
        _PickerField(
          label: 'Clock in (optional)',
          icon: Icons.login_rounded,
          value: _in == null ? null : _hhmm(_in!),
          onTap: () => _pickTime(true),
          onClear: () => setState(() => _in = null),
        ),
        _PickerField(
          label: 'Clock out (optional)',
          icon: Icons.logout_rounded,
          value: _out == null ? null : _hhmm(_out!),
          onTap: () => _pickTime(false),
          onClear: () => setState(() => _out = null),
        ),
        _ReasonField(_reason),
      ],
    );
  }
}
