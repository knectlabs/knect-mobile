import '../../../core/async/async_value.dart';
import '../data/requests_repository.dart';

class RequestsOverview {
  const RequestsOverview({
    required this.balances,
    required this.leave,
    required this.overtime,
    required this.corrections,
  });

  final List<LeaveBalance> balances;
  final List<LeaveRequest> leave;
  final List<OvertimeRequest> overtime;
  final List<CorrectionRequest> corrections;
}

/// The employee's balances and requests; forms reload it after submitting.
class RequestsCubit extends LoadCubit<RequestsOverview> {
  RequestsCubit(RequestsRepository repository)
      : super(() async {
          final results = await Future.wait<List<Object>>([
            repository.leaveBalances(),
            repository.leaveRequests(),
            repository.overtime(),
            repository.corrections(),
          ]);
          return RequestsOverview(
            balances: results[0].cast(),
            leave: results[1].cast(),
            overtime: results[2].cast(),
            corrections: results[3].cast(),
          );
        });
}
