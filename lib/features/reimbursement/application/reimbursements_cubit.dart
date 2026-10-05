import '../../../core/async/async_value.dart';
import '../data/reimbursement_repository.dart';

/// The employee's own reimbursement claims; load/refresh with [LoadCubit].
class ReimbursementsCubit extends LoadCubit<List<ReimbursementClaim>> {
  ReimbursementsCubit(ReimbursementRepository repository)
      : super(repository.list);
}
