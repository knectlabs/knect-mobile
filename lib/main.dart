import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/brand/brand.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/storage/device_identity.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_cubit.dart';
import 'features/approvals/data/approvals_repository.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/employee/data/directory_repository.dart';
import 'features/employee/data/employee_repository.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/requests/data/requests_repository.dart';
import 'features/shell/signed_in_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(config: config, tokenStorage: tokenStorage);
  final authRepository = ApiAuthRepository(
    api: apiClient,
    tokenStorage: tokenStorage,
    deviceIdentity: SecureDeviceIdentity(),
  );
  final authCubit = AuthCubit(authRepository);
  await authCubit.restoreSession();

  runApp(
    KnectApp(
      config: config,
      apiClient: apiClient,
      authRepository: authRepository,
      authCubit: authCubit,
    ),
  );
}

class KnectApp extends StatefulWidget {
  const KnectApp({
    required this.config,
    required this.apiClient,
    required this.authRepository,
    required this.authCubit,
    super.key,
  });

  final AppConfig config;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final AuthCubit authCubit;

  @override
  State<KnectApp> createState() => _KnectAppState();
}

class _KnectAppState extends State<KnectApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authCubit);
  }

  @override
  void dispose() {
    _appRouter.dispose();
    widget.authCubit.close();
    widget.apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.config),
        RepositoryProvider.value(value: widget.apiClient),
        RepositoryProvider<AuthRepository>.value(value: widget.authRepository),
        RepositoryProvider(create: (_) => EmployeeRepository(widget.apiClient)),
        RepositoryProvider(
            create: (_) => DirectoryRepository(widget.apiClient)),
        RepositoryProvider(
          create: (_) =>
              AttendanceRepository(widget.apiClient, SecureDeviceIdentity()),
        ),
        RepositoryProvider(create: (_) => RequestsRepository(widget.apiClient)),
        RepositoryProvider(
            create: (_) => ApprovalsRepository(widget.apiClient)),
        RepositoryProvider(
          create: (_) => NotificationsRepository(widget.apiClient),
        ),
      ],
      child: BlocProvider.value(
        value: widget.authCubit,
        child: MaterialApp.router(
          title: Brand.name,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: _appRouter.router,
          builder: (context, child) => _SessionScope(child: child!),
        ),
      ),
    );
  }
}

/// Wraps every route in [SignedInScope]. Its state is replaced on each new
/// sign-in and kept through sign-out until the router leaves the signed-in
/// pages; its cubits are lazy, so nothing loads on the sign-in screen.
class _SessionScope extends StatefulWidget {
  const _SessionScope({required this.child});

  final Widget child;

  @override
  State<_SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<_SessionScope> {
  int _session = 0;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          previous.status != AuthStatus.authenticated &&
          current.status == AuthStatus.authenticated,
      listener: (context, _) => setState(() => _session++),
      child: SignedInScope(key: ValueKey(_session), child: widget.child),
    );
  }
}
