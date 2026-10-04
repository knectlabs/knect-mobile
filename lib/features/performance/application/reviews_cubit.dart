import '../../../core/async/async_value.dart';
import '../data/performance_repository.dart';

/// The caller's review workload (tasks to write + submitted reviews about
/// them); load/refresh with [LoadCubit].
class ReviewsCubit extends LoadCubit<MyReviews> {
  ReviewsCubit(PerformanceRepository repository) : super(repository.myReviews);
}
