import 'dart:async';

import 'package:dio/dio.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';
import 'package:kerjancok_mobile/features/auth/data/auth_repository.dart';
import 'package:kerjancok_mobile/features/auth/domain/auth_models.dart';

const testUser = CurrentUser(
  id: 'user-1',
  email: 'rina.putri@acme.test',
  role: UserRole.employee,
  organization: OrganizationSummary(
    id: 'org-1',
    name: 'PT Acme Indonesia',
    code: 'ACME',
    timezone: 'Asia/Jakarta',
  ),
);

/// A `DioException` carrying [failure], as thrown by `ApiClient`.
DioException apiError(ApiFailure failure) => DioException(
      requestOptions: RequestOptions(path: '/'),
      error: failure,
    );

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.stored = false});

  bool stored;
  CurrentUser user = testUser;
  Object? signInError;
  Object? currentUserError;
  Object? signOutEverywhereError;
  final List<String> calls = [];
  final _expired = StreamController<void>.broadcast();

  void expireSession() => _expired.add(null);

  @override
  Stream<void> get sessionExpired => _expired.stream;

  @override
  Future<bool> hasStoredSession() async => stored;

  @override
  Future<CurrentUser> signIn({
    required String email,
    required String password,
  }) async {
    calls.add('signIn:$email');
    if (signInError case final error?) throw error;
    stored = true;
    return user;
  }

  @override
  Future<CurrentUser> currentUser() async {
    calls.add('currentUser');
    if (currentUserError case final error?) throw error;
    return user;
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    stored = false;
  }

  @override
  Future<void> signOutEverywhere() async {
    calls.add('signOutEverywhere');
    if (signOutEverywhereError case final error?) throw error;
    stored = false;
  }
}
