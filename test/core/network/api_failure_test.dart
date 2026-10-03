import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';

void main() {
  final request = RequestOptions(path: '/health');

  DioException badResponse(int statusCode, Object? data) {
    return DioException.badResponse(
      statusCode: statusCode,
      requestOptions: request,
      response: Response<Object?>(
        requestOptions: request,
        statusCode: statusCode,
        data: data,
      ),
    );
  }

  test('reads the documented API error envelope', () {
    final failure = ApiFailure.fromDioException(
      badResponse(400, {
        'error': {
          'code': 'REQUEST_VALIDATION_FAILED',
          'message': 'Request validation failed',
          'details': {
            'fields': [
              {
                'field': 'email',
                'rules': ['isEmail'],
              },
            ],
          },
        },
      }),
    );

    expect(failure.kind, ApiFailureKind.http);
    expect(failure.statusCode, 400);
    expect(failure.code, 'REQUEST_VALIDATION_FAILED');
    expect(failure.message, 'Request validation failed');
    expect(failure.details['fields'], isA<List<Object?>>());
  });

  test('flags unauthorized responses', () {
    final failure = ApiFailure.fromDioException(
      badResponse(401, {
        'error': {
          'code': 'UNAUTHORIZED',
          'message': 'Unauthorized',
          'details': <String, Object?>{},
        },
      }),
    );

    expect(failure.isUnauthorized, isTrue);
  });

  test('falls back safely for responses without the envelope', () {
    final failure = ApiFailure.fromDioException(
      badResponse(502, '<html>Bad gateway</html>'),
    );

    expect(failure.kind, ApiFailureKind.http);
    expect(failure.statusCode, 502);
    expect(failure.code, 'HTTP_ERROR');
    expect(failure.details, isEmpty);
  });

  test('classifies connectivity and timeout failures', () {
    expect(
      ApiFailure.fromDioException(
        DioException.connectionError(requestOptions: request, reason: 'down'),
      ).kind,
      ApiFailureKind.network,
    );
    expect(
      ApiFailure.fromDioException(
        DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: request,
        ),
      ).kind,
      ApiFailureKind.timeout,
    );
  });
}
