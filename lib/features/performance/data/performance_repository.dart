import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// A performance goal owned by (or about) the employee. Ratings/weights and the
/// target/current progress values stay as decimal strings — the client never
/// does performance math.
class PerformanceGoal {
  PerformanceGoal.fromJson(Json json)
      : id = json.str('id'),
        title = json.str('title'),
        description = json.strOrNull('description'),
        goalType = json.str('goalType'),
        targetValue = json.strOrNull('targetValue'),
        currentValue = json.strOrNull('currentValue'),
        weight = json.strOrNull('weight'),
        startDate = json.str('startDate'),
        endDate = json.str('endDate'),
        status = json.str('status');

  final String id;
  final String title;
  final String? description;
  final String goalType;
  final String? targetValue;
  final String? currentValue;
  final String? weight;
  final String startDate;
  final String endDate;

  /// `DRAFT` | `ACTIVE` | `COMPLETED` | `CANCELLED`.
  final String status;
}

/// One answer on a performance review. Ratings stay as decimal strings.
class ReviewAnswer {
  ReviewAnswer.fromJson(Json json)
      : id = json.strOrNull('id'),
        questionKey = json.str('questionKey'),
        rating = json.strOrNull('rating'),
        answer = json.strOrNull('answer');

  final String? id;
  final String questionKey;
  final String? rating;
  final String? answer;
}

/// A review task assigned to the caller or a submitted review about the caller.
/// Overall rating stays as a decimal string.
class PerformanceReview {
  PerformanceReview.fromJson(Json json)
      : id = json.str('id'),
        cycleName = json.obj('cycle').str('name'),
        employeeName = json.obj('employee').str('name'),
        reviewerName = json.obj('reviewer').str('name'),
        reviewType = json.str('reviewType'),
        status = json.str('status'),
        overallRating = json.strOrNull('overallRating'),
        submittedAt = json.timeOrNull('submittedAt'),
        answers = json
            .list('answers')
            .map(ReviewAnswer.fromJson)
            .toList(growable: false);

  final String id;
  final String cycleName;
  final String employeeName;
  final String reviewerName;

  /// `SELF` | `MANAGER` | `PEER` | `THREE_SIXTY`.
  final String reviewType;

  /// `PENDING` | `SUBMITTED`.
  final String status;
  final String? overallRating;
  final DateTime? submittedAt;
  final List<ReviewAnswer> answers;

  bool get isPending => status == 'PENDING';
  bool get isSubmitted => status == 'SUBMITTED';
}

/// The caller's review workload: tasks to write and submitted reviews about them.
class MyReviews {
  MyReviews.fromJson(Json json)
      : toWrite = json
            .list('toWrite')
            .map(PerformanceReview.fromJson)
            .toList(growable: false),
        aboutMe = json
            .list('aboutMe')
            .map(PerformanceReview.fromJson)
            .toList(growable: false);

  final List<PerformanceReview> toWrite;
  final List<PerformanceReview> aboutMe;
}

/// Reads/writes for the employee's own performance goals and review tasks
/// (Phase 3). Business rules live in the API; this only carries the contract.
class PerformanceRepository {
  PerformanceRepository(this._api);

  final ApiClient _api;

  Future<List<PerformanceGoal>> myGoals() async =>
      dataList(await _api.dio.get('/performance/goals/me'))
          .map(PerformanceGoal.fromJson)
          .toList();

  Future<void> createGoal({
    required String title,
    String? description,
    String? targetValue,
    String? currentValue,
    required String startDate,
    required String endDate,
  }) =>
      _api.dio.post('/performance/goals', data: {
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (targetValue != null && targetValue.isNotEmpty)
          'targetValue': targetValue,
        if (currentValue != null && currentValue.isNotEmpty)
          'currentValue': currentValue,
        'startDate': startDate,
        'endDate': endDate,
      });

  Future<void> updateGoal(
    String id, {
    String? currentValue,
    String? status,
  }) =>
      _api.dio.patch('/performance/goals/$id', data: {
        if (currentValue != null) 'currentValue': currentValue,
        if (status != null) 'status': status,
      });

  Future<MyReviews> myReviews() async =>
      MyReviews.fromJson(data(await _api.dio.get('/performance/reviews/me')));

  Future<PerformanceReview> reviewDetail(String id) async =>
      PerformanceReview.fromJson(
          data(await _api.dio.get('/performance/reviews/$id')));

  Future<void> saveReview(
    String id, {
    String? overallRating,
    required List<Map<String, Object?>> answers,
  }) =>
      _api.dio.patch('/performance/reviews/$id', data: {
        if (overallRating != null && overallRating.isNotEmpty)
          'overallRating': overallRating,
        'answers': answers,
      });

  Future<void> submitReview(String id) =>
      _api.dio.post('/performance/reviews/$id/submit');
}
