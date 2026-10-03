import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_failure.dart';

/// Request option: do not try to refresh the session when this call returns
/// 401 (sign-in and sign-out endpoints).
const skipAuthRefresh = 'kerjancok.skipAuthRefresh';
const _retried = 'kerjancok.retried';

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    Dio? dio,
    Dio? refreshDio,
  })  : dio = dio ?? Dio(),
        _refreshDio = refreshDio ?? Dio() {
    final options = BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    );
    this.dio.options = options;
    _refreshDio.options = options;
    this.dio.interceptors.addAll([
      _AccessTokenInterceptor(tokenStorage),
      _SessionRefreshInterceptor(
        plainDio: _refreshDio,
        tokenStorage: tokenStorage,
        onSessionExpired: _sessionExpired.add,
      ),
      _ApiFailureInterceptor(),
    ]);
  }

  final Dio dio;

  /// Interceptor-free client for token refresh and retries.
  final Dio _refreshDio;
  final _sessionExpired = StreamController<void>.broadcast();

  /// Emits when the API rejected the refresh token; stored tokens are cleared.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  void close() {
    dio.close(force: true);
    _refreshDio.close(force: true);
    _sessionExpired.close();
  }
}

class _AccessTokenInterceptor extends Interceptor {
  _AccessTokenInterceptor(this._tokenStorage);

  final TokenStorage _tokenStorage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _tokenStorage.readTokens();
    if (tokens != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }
}

/// Renews an expired access token once and retries the request.
///
/// The refresh call and the retry use an interceptor-free client: a retry that
/// re-entered this queued interceptor would wait on itself and never finish.
/// Its errors still pass through the remaining interceptors via the handler.
///
/// Refresh tokens are single-use and the API ends the whole session when a
/// used token is presented again, so 401 responses are handled one at a time
/// (`QueuedInterceptor`). A request that failed with an access token that has
/// since been replaced is retried with the new token instead of refreshing
/// again.
class _SessionRefreshInterceptor extends QueuedInterceptor {
  _SessionRefreshInterceptor({
    required Dio plainDio,
    required TokenStorage tokenStorage,
    required void Function(void) onSessionExpired,
  })  : _plainDio = plainDio,
        _tokenStorage = tokenStorage,
        _onSessionExpired = onSessionExpired;

  final Dio _plainDio;
  final TokenStorage _tokenStorage;
  final void Function(void) _onSessionExpired;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        request.extra[skipAuthRefresh] == true ||
        request.extra[_retried] == true) {
      return handler.next(err);
    }

    final tokens = await _tokenStorage.readTokens();
    if (tokens == null) return handler.next(err);

    var accessToken = tokens.accessToken;
    if (request.headers['Authorization'] == 'Bearer ${tokens.accessToken}') {
      try {
        final renewed = await _refresh(tokens.refreshToken);
        await _tokenStorage.writeTokens(renewed);
        accessToken = renewed.accessToken;
      } on DioException catch (refreshError) {
        if (refreshError.response?.statusCode == 401) {
          await _tokenStorage.clearTokens();
          _onSessionExpired(null);
        }
        return handler.next(err);
      }
    }

    request.headers['Authorization'] = 'Bearer $accessToken';
    request.extra[_retried] = true;
    try {
      handler.resolve(await _plainDio.fetch<Object?>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<AuthTokens> _refresh(String refreshToken) async {
    final response = await _plainDio.post<Map<String, Object?>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data?['data'];
    if (data is Map &&
        data['accessToken'] is String &&
        data['refreshToken'] is String) {
      return AuthTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
    }
    throw DioException.badResponse(
      statusCode: response.statusCode ?? 500,
      requestOptions: response.requestOptions,
      response: response,
    );
  }
}

/// Attaches a normalized [ApiFailure] as [DioException.error] so callers can
/// handle API errors without parsing response bodies themselves.
class _ApiFailureInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: ApiFailure.fromDioException(err)));
  }
}

/// Extracts the normalized failure from any error thrown by [ApiClient].
ApiFailure apiFailureOf(Object error) {
  if (error is DioException) {
    final attached = error.error;
    return attached is ApiFailure
        ? attached
        : ApiFailure.fromDioException(error);
  }
  return const ApiFailure(
    kind: ApiFailureKind.unknown,
    code: 'UNKNOWN',
    message: 'Something went wrong.',
  );
}
