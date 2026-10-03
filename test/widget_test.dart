import 'package:flutter_test/flutter_test.dart';
import 'package:kerjancok_mobile/core/config/app_config.dart';
import 'package:kerjancok_mobile/core/network/api_client.dart';
import 'package:kerjancok_mobile/core/storage/token_storage.dart';
import 'package:kerjancok_mobile/features/auth/application/auth_cubit.dart';
import 'package:kerjancok_mobile/main.dart';

import 'support/fake_token_storage.dart';

void main() {
  testWidgets('routes signed-out users to the login foundation',
      (tester) async {
    final dependencies = await _createDependencies();

    await tester.pumpWidget(
      KerjancokApp(
        config: dependencies.config,
        authCubit: dependencies.authCubit,
        apiClient: dependencies.apiClient,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kerjancok'), findsOneWidget);
    expect(
      find.text(
        'Employee access will be connected in the authentication phase.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('routes users with stored tokens to home', (tester) async {
    final dependencies = await _createDependencies(
      tokens: const AuthTokens(
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      ),
    );

    await tester.pumpWidget(
      KerjancokApp(
        config: dependencies.config,
        authCubit: dependencies.authCubit,
        apiClient: dependencies.apiClient,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Employee app foundation ready'), findsOneWidget);
  });
}

Future<({AppConfig config, AuthCubit authCubit, ApiClient apiClient})>
    _createDependencies({AuthTokens? tokens}) async {
  final config = AppConfig.fromEnvironment(
    environmentName: 'development',
    apiBaseUrl: 'http://localhost:3000/api/v1',
  );
  final storage = FakeTokenStorage(tokens);
  final authCubit = AuthCubit(storage);
  await authCubit.restoreSession();
  return (
    config: config,
    authCubit: authCubit,
    apiClient: ApiClient(config: config, tokenStorage: storage),
  );
}
