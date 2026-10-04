import '../../../core/async/async_value.dart';
import '../data/performance_repository.dart';

/// The caller's own performance goals; load/refresh with [LoadCubit].
class GoalsCubit extends LoadCubit<List<PerformanceGoal>> {
  GoalsCubit(PerformanceRepository repository) : super(repository.myGoals);
}
