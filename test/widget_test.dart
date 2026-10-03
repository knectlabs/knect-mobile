import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/config/app_config.dart';
import 'package:kerjancok_mobile/core/network/api_client.dart';
import 'package:kerjancok_mobile/core/network/api_failure.dart';
import 'package:kerjancok_mobile/features/auth/application/auth_cubit.dart';
import 'package:kerjancok_mobile/main.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_token_storage.dart';

Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  bool stored = false,
  FakeAuthRepository? repository,
}) async {
  final repo = repository ?? FakeAuthRepository(stored: stored);
  final config = AppConfig.fromEnvironment(
    environmentName: 'development',
    apiBaseUrl: 'http://localhost:3000/api/v1',
  );
  final authCubit = AuthCubit(repo);
  await authCubit.restoreSession();
  await tester.pumpWidget(
    KerjancokApp(
      config: config,
      apiClient: ApiClient(config: config, tokenStorage: FakeTokenStorage()),
      authRepository: repo,
      authCubit: authCubit,
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('routes signed-out users to sign in', (tester) async {
    await pumpApp(tester);

    expect(find.text('Sign in to Kerjancok'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('signs in and opens home', (tester) async {
    final repository = await pumpApp(tester);

    await tester.enterText(
      find.byKey(const Key('login.email')),
      'rina.putri@acme.test',
    );
    await tester.enterText(find.byKey(const Key('login.password')), 'secret');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('signIn:rina.putri@acme.test'));
    expect(find.text('Hello, rina.putri'), findsOneWidget);
    expect(find.text('PT Acme Indonesia'), findsOneWidget);
  });

  testWidgets('shows why sign-in failed', (tester) async {
    final repository = FakeAuthRepository()
      ..signInError = apiError(
        const ApiFailure(
          kind: ApiFailureKind.http,
          statusCode: 403,
          code: 'ACCOUNT_INACTIVE',
          message: 'This account has been deactivated.',
        ),
      );
    await pumpApp(tester, repository: repository);

    await tester.enterText(find.byKey(const Key('login.email')), 'a@b.test');
    await tester.enterText(find.byKey(const Key('login.password')), 'secret');
    await tester.tap(find.byKey(const Key('login.submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('has been deactivated'), findsOneWidget);
    expect(find.text('Sign in to Kerjancok'), findsOneWidget);
  });

  testWidgets('restores a session and signs out from profile', (tester) async {
    final repository = await pumpApp(tester, stored: true);
    expect(find.text('Hello, rina.putri'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('rina.putri@acme.test'), findsOneWidget);
    expect(find.text('Employee'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile.signOut')));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('signOut'));
    expect(find.text('Sign in to Kerjancok'), findsOneWidget);
  });

  testWidgets('returns to sign in with a notice when the session ends', (
    tester,
  ) async {
    final repository = await pumpApp(tester, stored: true);

    repository.expireSession();
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Kerjancok'), findsOneWidget);
    expect(find.textContaining('Your session has ended'), findsOneWidget);
  });
}
