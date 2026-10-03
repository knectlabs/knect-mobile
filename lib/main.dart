import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final tokenStorage = SecureTokenStorage();
  final authCubit = AuthCubit(tokenStorage);
  await authCubit.restoreSession();

  runApp(
    KerjancokApp(
      config: config,
      authCubit: authCubit,
      apiClient: ApiClient(config: config, tokenStorage: tokenStorage),
    ),
  );
}

class KerjancokApp extends StatefulWidget {
  const KerjancokApp({
    required this.config,
    required this.authCubit,
    required this.apiClient,
    super.key,
  });

  final AppConfig config;
  final AuthCubit authCubit;
  final ApiClient apiClient;

  @override
  State<KerjancokApp> createState() => _KerjancokAppState();
}

class _KerjancokAppState extends State<KerjancokApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authCubit);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    widget.apiClient.close();
    widget.authCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.config),
        RepositoryProvider.value(value: widget.apiClient),
      ],
      child: BlocProvider.value(
        value: widget.authCubit,
        child: MaterialApp.router(
          title: 'Kerjancok',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: _appRouter.router,
        ),
      ),
    );
  }
}
