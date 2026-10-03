import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';
import 'package:kerjancok_mobile/features/auth/application/auth_cubit.dart';
import 'package:kerjancok_mobile/features/auth/application/login_cubit.dart';

import '../../../support/fake_auth_repository.dart';

void main() {
  group('AuthCubit', () {
    test('starts signed out without a stored session', () async {
      final cubit = AuthCubit(FakeAuthRepository());

      await cubit.restoreSession();

      expect(cubit.state, const AuthState.unauthenticated());
      await cubit.close();
    });

    test('restores a stored session, then loads the profile', () async {
      final repository = FakeAuthRepository(stored: true);
      final cubit = AuthCubit(repository);

      await cubit.restoreSession();
      expect(cubit.state.status, AuthStatus.authenticated);
      await pumpEventQueue();

      expect(cubit.state, const AuthState.authenticated(testUser));
      await cubit.close();
    });

    test('stays signed in when the profile cannot load offline', () async {
      final repository = FakeAuthRepository(stored: true)
        ..currentUserError = StateError('offline');
      final cubit = AuthCubit(repository);

      await cubit.restoreSession();
      await pumpEventQueue();

      expect(cubit.state, const AuthState.authenticated());
      await cubit.close();
    });

    test('signs out with a notice when the API ends the session', () async {
      final repository = FakeAuthRepository(stored: true);
      final cubit = AuthCubit(repository);
      await cubit.restoreSession();

      repository.expireSession();
      await pumpEventQueue();

      expect(
          cubit.state, const AuthState.unauthenticated(sessionExpired: true));
      await cubit.close();
    });

    test('signs out locally and everywhere', () async {
      final repository = FakeAuthRepository(stored: true);
      final cubit = AuthCubit(repository)..signedIn(testUser);

      await cubit.signOut();
      expect(cubit.state, const AuthState.unauthenticated());

      cubit.signedIn(testUser);
      await cubit.signOutEverywhere();
      expect(cubit.state, const AuthState.unauthenticated());
      expect(repository.calls, ['signOut', 'signOutEverywhere']);
      await cubit.close();
    });

    test('keeps the session when signing out everywhere fails', () async {
      final repository = FakeAuthRepository(stored: true)
        ..signOutEverywhereError = StateError('offline');
      final cubit = AuthCubit(repository)..signedIn(testUser);

      await expectLater(cubit.signOutEverywhere(), throwsStateError);
      expect(cubit.state.status, AuthStatus.authenticated);
      await cubit.close();
    });
  });

  group('LoginCubit', () {
    test('signs in and authenticates the app', () async {
      final repository = FakeAuthRepository();
      final auth = AuthCubit(repository);
      final login = LoginCubit(repository, auth);

      await login.submit(email: 'rina.putri@acme.test', password: 'secret');

      expect(login.state, const LoginState());
      expect(auth.state, const AuthState.authenticated(testUser));
      await login.close();
      await auth.close();
    });

    test('clears the error when the user edits the form', () async {
      final repository = FakeAuthRepository();
      final auth = AuthCubit(repository);
      final login = LoginCubit(repository, auth);

      await login.submit(email: '', password: '');
      expect(login.state.error, isNotNull);
      login.clearError();

      expect(login.state, const LoginState());
      await login.close();
      await auth.close();
    });

    test('requires both fields', () async {
      final repository = FakeAuthRepository();
      final auth = AuthCubit(repository);
      final login = LoginCubit(repository, auth);

      await login.submit(email: ' ', password: '');

      expect(login.state.error, 'Enter your email and password.');
      expect(repository.calls, isEmpty);
      await login.close();
      await auth.close();
    });

    test('shows the API reason without signing in', () async {
      final repository = FakeAuthRepository()
        ..signInError = apiError(
          const ApiFailure(
            kind: ApiFailureKind.http,
            statusCode: 401,
            code: 'INVALID_CREDENTIALS',
            message: 'Invalid email or password.',
          ),
        );
      final auth = AuthCubit(repository);
      final login = LoginCubit(repository, auth);

      await login.submit(email: 'a@b.test', password: 'wrong');

      expect(login.state.error, 'Incorrect email or password.');
      expect(auth.state.status, isNot(AuthStatus.authenticated));
      await login.close();
      await auth.close();
    });
  });

  test('maps failures to sign-in messages', () {
    ApiFailure failure(String code,
            [ApiFailureKind kind = ApiFailureKind.http]) =>
        ApiFailure(kind: kind, code: code, message: code);

    expect(
      loginErrorMessage(failure('ACCOUNT_INACTIVE')),
      contains('deactivated'),
    );
    expect(
      loginErrorMessage(failure('ORGANIZATION_INACTIVE')),
      contains('organization'),
    );
    expect(
      loginErrorMessage(failure('TOO_MANY_REQUESTS')),
      contains('Too many'),
    );
    expect(
      loginErrorMessage(failure('NETWORK', ApiFailureKind.network)),
      contains('No connection'),
    );
    expect(
      loginErrorMessage(failure('TIMEOUT', ApiFailureKind.timeout)),
      contains('too long'),
    );
    expect(loginErrorMessage(failure('X')), 'Sign-in failed. Try again.');
  });
}
