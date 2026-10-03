import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/device_identity.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/auth_models.dart';

/// Session operations used by the auth cubits.
abstract interface class AuthRepository {
  Stream<void> get sessionExpired;

  Future<bool> hasStoredSession();

  Future<CurrentUser> signIn({required String email, required String password});

  Future<CurrentUser> currentUser();

  Future<void> signOut();

  Future<void> signOutEverywhere();
}

/// Authentication calls against kerjancok-api (06_API_CONVENTIONS.md §2).
/// Tokens never leave secure storage except as request headers/bodies.
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required ApiClient api,
    required TokenStorage tokenStorage,
    required DeviceIdentity deviceIdentity,
  })  : _api = api,
        _tokens = tokenStorage,
        _device = deviceIdentity;

  final ApiClient _api;
  final TokenStorage _tokens;
  final DeviceIdentity _device;

  /// Emits when the API rejected the session during an automatic refresh.
  @override
  Stream<void> get sessionExpired => _api.sessionExpired;

  @override
  Future<bool> hasStoredSession() async => await _tokens.readTokens() != null;

  /// Signs in and stores the issued tokens. Throws [DioException] carrying an
  /// `ApiFailure` on rejection.
  @override
  Future<CurrentUser> signIn({
    required String email,
    required String password,
  }) async {
    final device = await _device.current();
    final response = await _api.dio.post<Object?>(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
        'device': device.toJson(),
      },
      options: Options(extra: {skipAuthRefresh: true}),
    );
    final session = AuthSession.fromJson(unwrapData(response.data));
    await _tokens.writeTokens(session.tokens);
    return session.user;
  }

  @override
  Future<CurrentUser> currentUser() async {
    final response = await _api.dio.get<Object?>('/auth/me');
    return CurrentUser.fromJson(unwrapData(response.data));
  }

  /// Ends this device's session on the API (best effort) and locally.
  @override
  Future<void> signOut() async {
    final tokens = await _tokens.readTokens();
    if (tokens != null) {
      try {
        await _api.dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': tokens.refreshToken},
          options: Options(extra: {skipAuthRefresh: true}),
        );
      } on DioException {
        // Offline or already revoked: the local session still ends.
      }
    }
    await _tokens.clearTokens();
  }

  /// Ends every session of this user on every device, then locally. Throws
  /// when the API could not be reached, so the user is not told other
  /// devices were signed out when they were not.
  @override
  Future<void> signOutEverywhere() async {
    await _api.dio.post<void>('/auth/logout-all');
    await _tokens.clearTokens();
  }
}
