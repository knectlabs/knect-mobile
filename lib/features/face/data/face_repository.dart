import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';

/// The employee's own face-enrollment status. Mirrors the API `FaceStatusDto`
/// and NEVER carries the embedding vector.
class FaceStatus {
  FaceStatus.fromJson(Json json)
      : enrolled = json.flag('enrolled'),
        activeCount = json.integer('activeCount'),
        modelId = json.strOrNull('modelId'),
        lastEnrolledAt = json.timeOrNull('lastEnrolledAt');

  final bool enrolled;
  final int activeCount;
  final String? modelId;
  final DateTime? lastEnrolledAt;
}

/// Self-service face enrollment for the authenticated employee. The server is
/// authoritative for the 1:1 match decision; this only enrolls/reads/resets the
/// employee's own reference embeddings. The vector is a biometric secret and is
/// never logged.
class FaceRepository {
  FaceRepository(this._api);

  final ApiClient _api;

  /// Current enrollment status (`GET /face/me`).
  Future<FaceStatus> status() async =>
      FaceStatus.fromJson(data(await _api.dio.get('/face/me')));

  /// Enrolls a reference embedding (`POST /face/enroll`). The server
  /// re-normalizes and stores it; multiple active references are allowed.
  Future<FaceStatus> enroll({
    required List<double> vector,
    required int dimension,
    required String modelId,
  }) async =>
      FaceStatus.fromJson(data(await _api.dio.post('/face/enroll', data: {
        'modelId': modelId,
        'dimension': dimension,
        'vector': vector,
      })));

  /// Deactivates all of the employee's reference embeddings
  /// (`DELETE /face/me`).
  Future<FaceStatus> reset() async =>
      FaceStatus.fromJson(data(await _api.dio.delete('/face/me')));
}
