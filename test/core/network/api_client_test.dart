import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/config/app_config.dart';
import 'package:kerjancok_mobile/core/network/api_client.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';
import 'package:kerjancok_mobile/core/storage/token_storage.dart';

import '../../support/fake_token_storage.dart';

typedef Responder = FutureOr<ResponseBody> Function(RequestOptions options);

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ResponseBody unauthorized() => json(401, {
      'error': {
        'code': 'UNAUTHORIZED',
        'message': 'Unauthorized',
        'details': {}
      },
    });

class RoutingAdapter implements HttpClientAdapter {
  RoutingAdapter(this.responder);

  final Responder responder;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

const oldTokens =
    AuthTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
const newTokens =
    AuthTokens(accessToken: 'access-2', refreshToken: 'refresh-2');

Map<String, Object?> sessionBody(AuthTokens tokens) => {
      'data': {
        'tokenType': 'Bearer',
        'accessToken': tokens.accessToken,
        'refreshToken': tokens.refreshToken,
      },
    };

void main() {
  final config = AppConfig.fromEnvironment(
    apiBaseUrl: 'https://api.example.com/api/v1',
  );

  late FakeTokenStorage storage;
  late RoutingAdapter api;

  /// Interceptor-free client used for `/auth/refresh` and retries.
  late RoutingAdapter plain;

  List<RequestOptions> refreshCalls() => plain.requests
      .where((request) => request.path == '/auth/refresh')
      .toList();
  late ApiClient client;

  /// Protected endpoints accept only the newest access token.
  ResponseBody protectedEndpoint(RequestOptions options) =>
      options.headers['Authorization'] == 'Bearer access-2'
          ? json(200, {
              'data': {'ok': true},
            })
          : unauthorized();

  void setUpClient({
    Responder? apiResponder,
    Responder? refreshResponder,
  }) {
    storage = FakeTokenStorage(oldTokens);
    final protected = apiResponder ?? protectedEndpoint;
    final refresh =
        refreshResponder ?? (_) => json(200, sessionBody(newTokens));
    api = RoutingAdapter(protected);
    plain = RoutingAdapter(
      (options) => options.path == '/auth/refresh'
          ? refresh(options)
          : protected(options),
    );
    client = ApiClient(
      config: config,
      tokenStorage: storage,
      dio: Dio()..httpClientAdapter = api,
      refreshDio: Dio()..httpClientAdapter = plain,
    );
  }

  tearDown(() => client.close());

  test('configures the base URL and attaches the stored access token',
      () async {
    setUpClient(apiResponder: (_) => json(200, {'data': {}}));

    await client.dio.get<void>('/health');

    final request = api.requests.single;
    expect(request.uri.toString(), 'https://api.example.com/api/v1/health');
    expect(request.headers['Authorization'], 'Bearer access-1');
    expect(request.headers['Accept'], 'application/json');
  });

  test('omits the authorization header without a session', () async {
    setUpClient(apiResponder: (_) => json(200, {'data': {}}));
    storage.tokens = null;

    await client.dio.get<void>('/health');

    expect(api.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('refreshes an expired access token once and retries', () async {
    setUpClient();

    final response = await client.dio.get<Object?>('/auth/me');

    expect(response.statusCode, 200);
    expect(refreshCalls(), hasLength(1));
    expect(refreshCalls().single.data, {'refreshToken': 'refresh-1'});
    expect(storage.tokens, newTokens);
    expect(plain.requests.last.headers['Authorization'], 'Bearer access-2');
  });

  test('serializes concurrent 401s into a single refresh', () async {
    setUpClient();

    final responses = await Future.wait([
      client.dio.get<Object?>('/a'),
      client.dio.get<Object?>('/b'),
      client.dio.get<Object?>('/c'),
    ]);

    expect(responses.map((r) => r.statusCode), everyElement(200));
    expect(refreshCalls(), hasLength(1));
  });

  test('ends the session when the API rejects the refresh token', () async {
    setUpClient(refreshResponder: (_) => unauthorized());
    final expired = expectLater(client.sessionExpired, emits(null));

    final error = await client.dio
        .get<Object?>('/auth/me')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(apiFailureOf(error!).isUnauthorized, isTrue);
    expect(storage.tokens, isNull);
    await expired;
  });

  test('keeps the session when refreshing fails for network reasons', () async {
    setUpClient(
      refreshResponder: (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      ),
    );

    await expectLater(
        client.dio.get<Object?>('/auth/me'), throwsA(isA<DioException>()));
    expect(storage.tokens, oldTokens);
  });

  test('does not refresh for sign-in or sign-out requests', () async {
    setUpClient(apiResponder: (_) => unauthorized());

    final error = await client.dio
        .post<Object?>(
          '/auth/login',
          options: Options(extra: {skipAuthRefresh: true}),
        )
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(refreshCalls(), isEmpty);
    expect(apiFailureOf(error!).isUnauthorized, isTrue);
  });

  test('does not retry more than once', () async {
    setUpClient(apiResponder: (_) => unauthorized());

    await expectLater(
      client.dio.get<Object?>('/auth/me'),
      throwsA(isA<DioException>()),
    );
    expect(refreshCalls(), hasLength(1));
    // Original request, then exactly one retry.
    expect(api.requests, hasLength(1));
    expect(plain.requests.where((r) => r.path == '/auth/me'), hasLength(1));
  });

  test('exposes API errors as ApiFailure', () async {
    setUpClient(
      apiResponder: (_) => json(503, {
        'error': {
          'code': 'SERVICE_UNAVAILABLE',
          'message': 'Internal server error',
          'details': {},
        },
      }),
    );

    final error = await client.dio
        .get<void>('/health')
        .then<Object?>((_) => null, onError: (Object e) => e);

    final failure = apiFailureOf(error!);
    expect(failure.code, 'SERVICE_UNAVAILABLE');
    expect(failure.statusCode, 503);
    expect(apiFailureOf(StateError('x')).kind, ApiFailureKind.unknown);
  });
}
