import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/async/async_value.dart';
import '../../../core/time/format.dart';
import '../../../shared/widgets/state_views.dart';
import '../../shell/signed_in_scope.dart';
import '../data/attendance_repository.dart';
import 'today_card.dart';

class _HistoryCubit extends LoadCubit<List<AttendanceRecord>> {
  _HistoryCubit(AttendanceRepository repository) : super(repository.history);
}

/// Attendance tab: today's action and the last records.
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _HistoryCubit(context.read<AttendanceRepository>()),
      child: BlocListener<TodayCubit, AsyncValue<TodayStatus>>(
        // A new clock action changes history too.
        listenWhen: (previous, current) => current is AsyncData,
        listener: (context, _) => context.read<_HistoryCubit>().load(),
        child: const _AttendanceView(),
      ),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<_HistoryCubit>().state;
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          context.read<TodayCubit>().load(),
          context.read<_HistoryCubit>().load(),
        ]),
        child: CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
              sliver: SliverToBoxAdapter(child: TodayCard()),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: Text('History', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            SliverToBoxAdapter(
              child: AsyncView(
                value: history,
                onRetry: context.read<_HistoryCubit>().load,
                loading: const SizedBox(height: 320, child: SkeletonList(count: 3)),
                builder: (records) => records.isEmpty
                    ? const EmptyView(
                        icon: Icons.event_available_outlined,
                        title: 'No attendance yet',
                        message: 'Your clock-ins will appear here.',
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Column(
                            children: [
                              for (final (index, record) in records.indexed) ...[
                                if (index > 0) const Divider(height: 1, indent: 16),
                                _HistoryTile(record: record),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String time(DateTime? value) =>
        value == null ? '--:--' : Clock.hm(value, record.timezone);
    final (label, tone) = switch (record.status) {
      'PRESENT' => ('Present', StatusTone.success),
      'LATE' => ('Late ${Clock.duration(record.lateMinutes)}', StatusTone.warning),
      'ABSENT' => ('Absent', StatusTone.danger),
      'LEAVE' => ('Leave', StatusTone.neutral),
      'SICK' => ('Sick', StatusTone.neutral),
      'OFF_DAY' => ('Off day', StatusTone.neutral),
      'HOLIDAY' => ('Holiday', StatusTone.neutral),
      final other => (other, StatusTone.neutral),
    };
    return ListTile(
      title: Text(Clock.date(record.date)),
      subtitle: Text(
        '${time(record.clockInAt)} – ${time(record.clockOutAt)}'
        '${record.workMinutes == null ? '' : ' · ${Clock.duration(record.workMinutes!)}'}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusChip(label, tone: tone),
          if (record.isSuspicious)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Under review',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
