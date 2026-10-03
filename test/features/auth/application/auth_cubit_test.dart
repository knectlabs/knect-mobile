import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/storage/token_storage.dart';
import 'package:kerjancok_mobile/features/auth/application/auth_cubit.dart';

import '../../../support/fake_token_storage.dart';

void main() {
  const tokens = AuthTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
  );

  test('restores an authenticated session when tokens exist', () async {
    final cubit = AuthCubit(FakeTokenStorage(tokens));

    await cubit.restoreSession();

    expect(cubit.state, const AuthState.authenticated());
    await cubit.close();
  });

  test('falls back to signed out when secure storage fails', () async {
    final storage = FakeTokenStorage()..readError = StateError('unavailable');
    final cubit = AuthCubit(storage);

    await cubit.restoreSession();

    expect(cubit.state, const AuthState.unauthenticated());
    await cubit.close();
  });

  test('persists and clears a session', () async {
    final storage = FakeTokenStorage();
    final cubit = AuthCubit(storage);

    await cubit.establishSession(tokens);
    expect(storage.tokens, tokens);
    expect(cubit.state, const AuthState.authenticated());

    await cubit.signOut();
    expect(storage.tokens, isNull);
    expect(cubit.state, const AuthState.unauthenticated());
    await cubit.close();
  });
}
