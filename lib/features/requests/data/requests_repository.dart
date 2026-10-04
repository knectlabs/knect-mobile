import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

class LeaveType {
  LeaveType.fromJson(Json json)
      : id = json.str('id'),
        name = json.str('name'),
        paid = json['paid'] == true,
        requiresProof = json['requiresProof'] == true,
        minimumNoticeDays = json.intOrNull('minimumNoticeDays') ?? 0;

  final String id;
  final String name;
  final bool paid;
  final bool requiresProof;
  final int minimumNoticeDays;
}

class LeaveBalance {
  LeaveBalance.fromJson(Json json)
      : leaveTypeId = json.obj('leaveType').str('id'),
        leaveTypeName = json.obj('leaveType').str('name'),
        year = json.integer('year'),
        remaining = (json['remaining'] as num).toDouble(),
        pending = (json['pending'] as num).toDouble(),
        available = (json['available'] as num).toDouble();

  final String leaveTypeId;
  final String leaveTypeName;
  final int year;
  final double remaining;
  final double pending;
  final double available;
}

/// Common shape of the employee's own requests for list display.
sealed class EmployeeRequest {
  EmployeeRequest(Json json)
      : id = json.str('id'),
        status = json.str('status'),
        reason = json.strOrNull('reason') ?? '',
        submittedAt = json.time('submittedAt');

  final String id;
  final String status;
  final String reason;
  final DateTime submittedAt;

  bool get isPending => status == 'PENDING';
}

class LeaveRequest extends EmployeeRequest {
  LeaveRequest.fromJson(super.json)
      : leaveTypeName = json.obj('leaveType').str('name'),
        startDate = json.str('startDate'),
        endDate = json.str('endDate'),
        requestedDays = (json['requestedDays'] as num).toDouble();

  final String leaveTypeName;
  final String startDate;
  final String endDate;
  final double requestedDays;
}

class OvertimeRequest extends EmployeeRequest {
  OvertimeRequest.fromJson(super.json)
      : date = json.str('date'),
        startAt = json.time('startAt'),
        endAt = json.time('endAt'),
        requestedMinutes = json.integer('requestedMinutes'),
        approvedMinutes = json.intOrNull('approvedMinutes');

  final String date;
  final DateTime startAt;
  final DateTime endAt;
  final int requestedMinutes;
  final int? approvedMinutes;
}

class CorrectionRequest extends EmployeeRequest {
  CorrectionRequest.fromJson(super.json)
      : date = json.str('date'),
        clockInAt = json.timeOrNull('requestedClockInAt'),
        clockOutAt = json.timeOrNull('requestedClockOutAt');

  final String date;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
}

class RequestsRepository {
  RequestsRepository(this._api);

  final ApiClient _api;

  Future<List<LeaveType>> leaveTypes() async => dataList(
        await _api.dio.get('/leave-types', queryParameters: {'limit': 100}),
      ).map(LeaveType.fromJson).toList();

  Future<List<LeaveBalance>> leaveBalances() async =>
      dataList(await _api.dio.get('/leave-balances/me'))
          .map(LeaveBalance.fromJson)
          .toList();

  Future<List<LeaveRequest>> leaveRequests() async => dataList(
        await _api.dio
            .get('/leave-requests/me', queryParameters: {'limit': 50}),
      ).map(LeaveRequest.fromJson).toList();

  Future<List<OvertimeRequest>> overtime() async => dataList(
        await _api.dio.get('/overtime/me', queryParameters: {'limit': 50}),
      ).map(OvertimeRequest.fromJson).toList();

  Future<List<CorrectionRequest>> corrections() async => dataList(
        await _api.dio
            .get('/attendance-corrections/me', queryParameters: {'limit': 50}),
      ).map(CorrectionRequest.fromJson).toList();

  Future<void> submitLeave({
    required String leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
  }) =>
      _api.dio.post('/leave-requests', data: {
        'leaveTypeId': leaveTypeId,
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      });

  Future<void> submitOvertime({
    required String date,
    required String startTime,
    required String endTime,
    required String reason,
  }) =>
      _api.dio.post('/overtime', data: {
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'reason': reason,
      });

  Future<void> submitCorrection({
    required String date,
    DateTime? clockInAt,
    DateTime? clockOutAt,
    required String reason,
  }) =>
      _api.dio.post('/attendance-corrections', data: {
        'date': date,
        if (clockInAt != null) 'clockInAt': clockInAt.toUtc().toIso8601String(),
        if (clockOutAt != null)
          'clockOutAt': clockOutAt.toUtc().toIso8601String(),
        'reason': reason,
      });

  Future<void> cancel(EmployeeRequest request) {
    final path = switch (request) {
      LeaveRequest() => '/leave-requests',
      OvertimeRequest() => '/overtime',
      CorrectionRequest() => '/attendance-corrections',
    };
    return _api.dio.post('$path/${request.id}/cancel');
  }
}
