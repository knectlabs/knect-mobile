import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

class Approval {
  Approval.fromJson(Json json)
      : id = json.str('id'),
        targetType = json.str('targetType'),
        status = json.str('status'),
        requesterName = json.obj('requester').str('name'),
        title = json.objOrNull('summary')?.str('title'),
        subtitle = json.objOrNull('summary')?.strOrNull('subtitle'),
        comment = json
            .list('steps')
            .map((step) => step.strOrNull('comment'))
            .whereType<String>()
            .lastOrNull,
        createdAt = json.time('createdAt');

  final String id;

  /// `LEAVE_REQUEST`, `OVERTIME_REQUEST`, or `ATTENDANCE_CORRECTION`.
  final String targetType;
  final String status;
  final String requesterName;
  final String? title;
  final String? subtitle;
  final String? comment;
  final DateTime createdAt;

  bool get isOvertime => targetType == 'OVERTIME_REQUEST';

  String get typeLabel => switch (targetType) {
        'LEAVE_REQUEST' => 'Leave',
        'OVERTIME_REQUEST' => 'Overtime',
        'ATTENDANCE_CORRECTION' => 'Correction',
        'ATTENDANCE_LOCATION' => 'Outside location attendance',
        _ => targetType,
      };
}

class ApprovalsRepository {
  ApprovalsRepository(this._api);

  final ApiClient _api;

  Future<List<Approval>> inbox({required bool pending}) async => dataList(
        await _api.dio.get('/approvals/me', queryParameters: {
          'view': pending ? 'pending' : 'decided',
          'limit': 50,
        }),
      ).map(Approval.fromJson).toList();

  Future<void> decide(
    String id, {
    required bool approve,
    String? comment,
    int? approvedMinutes,
  }) =>
      _api.dio.post(
        '/approvals/$id/${approve ? 'approve' : 'reject'}',
        data: {
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (approvedMinutes != null) 'approvedMinutes': approvedMinutes,
        },
      );
}
