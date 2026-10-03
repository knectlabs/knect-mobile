import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/config/app_config.dart';
import 'package:kerjancok_mobile/core/network/api_client.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';
import 'package:kerjancok_mobile/core/storage/token_storage.dart';

import '../../support/fake_token_storage.dart';

void main() {
  final config = AppConfig.fromEnvironment(
    apiBaseUrl: 'https://api.example.com/api/v1',
  );

  ApiClient createClient(_RecordingAdapter adapter, {AuthTokens? tokens}) {
    final dio = Dio()..httpClientAdapter = adapter;
    return ApiClient(
      config: config,
      tokenStorage: FakeTokenStorage(tokens),
      dio: dio,
    );
  }

  test(
    'configures the base URL and attaches the stored access token',
    () async {
      final adapter = _RecordingAdapter();
      final client = createClient(
        adapter,
        tokens: const AuthTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
        ),
      );

      await client.dio.get<void>('/health');

      expect(
        adapter.request?.uri.toString(),
        'https://api.example.com/api/v1/health',
      );
      expect(adapter.request?.headers['Authorization'], 'Bearer access-token');
      expect(adapter.request?.headers['Accept'], 'application/json');
      client.close();
    },
  );

  test('omits the authorization header without a session', () async {
    final adapter = _RecordingAdapter();
    final client = createClient(adapter);

    await client.dio.get<void>('/health');

    expect(adapter.request?.headers.containsKey('Authorization'), isFalse);
    client.close();
  });

  test('exposes API errors as ApiFailure', () async {
    final adapter = _RecordingAdapter(
      statusCode: 503,
      body: '{"error":{"code":"SERVICE_UNAVAILABLE",'
          '"message":"Internal server error","details":{}}}',
    );
    final client = createClient(adapter);

    final error = await client.dio
        .get<void>('/health')
        .then<Object?>((_) => null, onError: (Object error) => error);

    expect(error, isA<DioException>());
    final failure = (error! as DioException).error;
    expect(failure, isA<ApiFailure>());
    failure as ApiFailure;
    expect(failure.code, 'SERVICE_UNAVAILABLE');
    expect(failure.statusCode, 503);
    client.close();
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.body = '{}'});

  final int statusCode;
  final String body;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
