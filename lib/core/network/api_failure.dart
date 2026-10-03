import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

enum ApiFailureKind {
  /// The device could not reach the API.
  network,

  /// The request exceeded a configured timeout.
  timeout,

  /// The API answered with an HTTP error status.
  http,

  /// The request was cancelled by the client.
  cancelled,

  /// Anything that does not fit the categories above.
  unknown,
}

/// Client-safe representation of a failed API call.
///
/// HTTP failures carry the documented error envelope
/// `{"error": {"code", "message", "details"}}` when the API returned one.
class ApiFailure extends Equatable implements Exception {
  const ApiFailure({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  factory ApiFailure.fromDioException(DioException exception) {
    return switch (exception.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const ApiFailure(
          kind: ApiFailureKind.timeout,
          code: 'TIMEOUT',
          message: 'The server took too long to respond.',
        ),
      DioExceptionType.connectionError => const ApiFailure(
          kind: ApiFailureKind.network,
          code: 'NETWORK_UNAVAILABLE',
          message: 'Unable to reach the server.',
        ),
      DioExceptionType.cancel => const ApiFailure(
          kind: ApiFailureKind.cancelled,
          code: 'CANCELLED',
          message: 'The request was cancelled.',
        ),
      DioExceptionType.badResponse => _fromResponse(exception.response),
      _ => const ApiFailure(
          kind: ApiFailureKind.unknown,
          code: 'UNKNOWN',
          message: 'Something went wrong.',
        ),
    };
  }

  static ApiFailure _fromResponse(Response<Object?>? response) {
    final statusCode = response?.statusCode;
    final body = response?.data;
    if (body case {'error': final Map<Object?, Object?> error}) {
      final code = error['code'];
      final message = error['message'];
      final details = error['details'];
      if (code is String && message is String) {
        return ApiFailure(
          kind: ApiFailureKind.http,
          statusCode: statusCode,
          code: code,
          message: message,
          details: details is Map
              ? Map<String, Object?>.unmodifiable(
                  details.cast<String, Object?>())
              : const {},
        );
      }
    }
    return ApiFailure(
      kind: ApiFailureKind.http,
      statusCode: statusCode,
      code: 'HTTP_ERROR',
      message: 'The server returned an unexpected response.',
    );
  }

  final ApiFailureKind kind;
  final int? statusCode;
  final String code;
  final String message;
  final Map<String, Object?> details;

  bool get isUnauthorized => statusCode == 401;

  @override
  List<Object?> get props => [kind, statusCode, code, message, details];

  @override
  String toString() => 'ApiFailure($kind, $statusCode, $code)';
}
