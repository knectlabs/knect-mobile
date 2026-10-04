import '../../../core/async/async_value.dart';
import '../data/payslip_repository.dart';

/// The employee's own finalized payslips; load/refresh with [LoadCubit].
class PayslipsCubit extends LoadCubit<List<PayslipSummary>> {
  PayslipsCubit(PayslipRepository repository) : super(repository.list);
}
