import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/application/auth_cubit.dart';
import '../application/goals_cubit.dart';
import '../data/performance_repository.dart';
import 'performance_format.dart';

/// The employee's own performance goals (Phase 3). Lists goals with progress,
/// supports creating a goal and updating its progress/status. Handles
/// loading/empty/error/refresh.
class MyGoalsScreen extends StatelessWidget {
  const MyGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GoalsCubit(context.read<PerformanceRepository>()),
      child: const _MyGoalsView(),
    );
  }
}

class _MyGoalsView extends StatelessWidget {
  const _MyGoalsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<GoalsCubit>().state;
    final load = context.read<GoalsCubit>().load;
    return Scaffold(
      appBar: AppBar(title: const Text('My Goals')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('goals.create'),
        onPressed: () => _openGoalForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
          children: [
            AsyncView<List<PerformanceGoal>>(
              value: state,
              onRetry: load,
              loading:
                  const SizedBox(height: 320, child: SkeletonList(count: 3)),
              builder: (goals) {
                if (goals.isEmpty) {
                  return const EmptyView(
                    icon: Icons.flag_outlined,
                    title: 'No goals yet',
                    message:
                        'Create a goal to track your progress for this period.',
                  );
                }
                return Column(
                  children: [
                    for (final goal in goals)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GoalCard(goal: goal),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final PerformanceGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        key: Key('goal.item.${goal.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openGoalForm(context, goal: goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                    goalStatusLabel(goal.status),
                    tone: goalStatusTone(goal.status),
                  ),
                ],
              ),
              if (goal.description != null &&
                  goal.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  goal.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.trending_up,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Progress ${goalProgress(currentValue: goal.currentValue, targetValue: goal.targetValue)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    '${Clock.shortDate(goal.startDate)} – ${Clock.shortDate(goal.endDate)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openGoalForm(BuildContext context, {PerformanceGoal? goal}) {
  final cubit = context.read<GoalsCubit>();
  final repository = context.read<PerformanceRepository>();
  final timezone =
      context.read<AuthCubit>().state.user?.organization.timezone;
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute(
      builder: (_) => RepositoryProvider.value(
        value: repository,
        child: BlocProvider.value(
          value: cubit,
          child: _GoalFormScreen(goal: goal, timezone: timezone),
        ),
      ),
    ),
  );
}

/// Create a goal or update an existing goal's progress/status.
class _GoalFormScreen extends StatefulWidget {
  const _GoalFormScreen({required this.goal, required this.timezone});

  final PerformanceGoal? goal;
  final String? timezone;

  @override
  State<_GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<_GoalFormScreen> {
  late final TextEditingController _title =
      TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.goal?.description ?? '');
  late final TextEditingController _target =
      TextEditingController(text: widget.goal?.targetValue ?? '');
  late final TextEditingController _current =
      TextEditingController(text: widget.goal?.currentValue ?? '');
  late String _status = widget.goal?.status ?? 'ACTIVE';
  DateTime? _start;
  DateTime? _end;

  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.goal != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _target.dispose();
    _current.dispose();
    super.dispose();
  }

  String? _validate() {
    if (!_isEdit) {
      if (_title.text.trim().isEmpty) return 'Add a goal title.';
      if (_start == null || _end == null) {
        return 'Choose the start and end dates.';
      }
    }
    return null;
  }

  Future<void> _send() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final repository = context.read<PerformanceRepository>();
    final goals = context.read<GoalsCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await repository.updateGoal(
          widget.goal!.id,
          currentValue: _current.text.trim(),
          status: _status,
        );
      } else {
        await repository.createGoal(
          title: _title.text.trim(),
          description: _description.text.trim(),
          targetValue: _target.text.trim(),
          currentValue: _current.text.trim(),
          startDate: Clock.iso(_start!),
          endDate: Clock.iso(_end!),
        );
      }
      goals.load();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Goal updated.' : 'Goal created.'),
          behavior: SnackBarBehavior.floating,
        ),
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
    final today = Clock.today(widget.timezone);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Update goal' : 'New goal')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            TextField(
              key: const Key('goal.title'),
              controller: _title,
              enabled: !_isEdit,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('goal.description'),
              controller: _description,
              enabled: !_isEdit,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('goal.current'),
                    controller: _current,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Current value',
                      prefixIcon: Icon(Icons.trending_up),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('goal.target'),
                    controller: _target,
                    enabled: !_isEdit,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target value',
                      prefixIcon: Icon(Icons.outlined_flag),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isEdit)
              DropdownButtonFormField<String>(
                key: const Key('goal.status'),
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.flag_circle_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(
                      value: 'COMPLETED', child: Text('Completed')),
                  DropdownMenuItem(
                      value: 'CANCELLED', child: Text('Cancelled')),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? _status),
              )
            else ...[
              _DateField(
                label: 'Start date',
                value: _start,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _start ?? today,
                    firstDate: today.subtract(const Duration(days: 365)),
                    lastDate: today.add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _start = picked;
                      if (_end == null || _end!.isBefore(picked)) {
                        _end = picked;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              _DateField(
                label: 'End date',
                value: _end,
                onTap: () async {
                  final first = _start ?? today;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _end ?? first,
                    firstDate: first,
                    lastDate: today.add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => _end = picked);
                },
              ),
            ],
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
          key: const Key('goal.submit'),
          onPressed: _busy ? null : _send,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEdit ? 'Save changes' : 'Create goal'),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        isEmpty: value == null,
        child: value == null ? null : Text(Clock.date(value!)),
      ),
    );
  }
}
