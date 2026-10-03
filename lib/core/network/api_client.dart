import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_failure.dart';

class ApiClient {
  ApiClient({
    required AppConfig config,
    required TokenStorage tokenStorage,
    Dio? dio,
  }) : dio = dio ?? Dio() {
    this.dio.options = BaseOptions(
      baseUrl: config.apiBaseUri.toString(),
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Accept': 'application/json'},
    );
    this.dio.interceptors.addAll([
      _AccessTokenInterceptor(tokenStorage),
      _ApiFailureInterceptor(),
    ]);
  }

  final Dio dio;

  void close() => dio.close(force: true);
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

/// Attaches a normalized [ApiFailure] as [DioException.error] so callers can
/// handle API errors without parsing response bodies themselves.
class _ApiFailureInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: ApiFailure.fromDioException(err)));
  }
}
