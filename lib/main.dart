import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/brand/brand.dart';
import 'core/config/app_config.dart';
import 'core/network/api_client.dart';
import 'core/notifications/firebase_notifications.dart';
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
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final config = AppConfig.fromEnvironment();
  final tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(config: config, tokenStorage: tokenStorage);
  final deviceIdentity = SecureDeviceIdentity();
  final firebaseNotifications = FirebaseNotifications(
    api: apiClient,
    deviceIdentity: deviceIdentity,
  );
  final authRepository = ApiAuthRepository(
    api: apiClient,
    tokenStorage: tokenStorage,
    deviceIdentity: deviceIdentity,
    beforeSignOut: firebaseNotifications.unregister,
  );
  final authCubit = AuthCubit(authRepository);
  await authCubit.restoreSession();

  runApp(
    KnectApp(
      config: config,
      apiClient: apiClient,
      authRepository: authRepository,
      authCubit: authCubit,
      firebaseNotifications: firebaseNotifications,
    ),
  );
}

class KnectApp extends StatefulWidget {
  const KnectApp({
    required this.config,
    required this.apiClient,
    required this.authRepository,
    required this.authCubit,
    this.firebaseNotifications,
    super.key,
  });

  final AppConfig config;
  final ApiClient apiClient;
  final AuthRepository authRepository;
  final AuthCubit authCubit;
  final FirebaseNotifications? firebaseNotifications;

  @override
  State<KnectApp> createState() => _KnectAppState();
}

class _KnectAppState extends State<KnectApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authCubit);
    widget.firebaseNotifications?.setHandlers(
      onForeground: _showForegroundNotification,
      onOpened: _openNotification,
    );
    if (widget.authCubit.state.status == AuthStatus.authenticated) {
      unawaited(widget.firebaseNotifications!.start());
    }
  }

  @override
  void dispose() {
    _appRouter.dispose();
    widget.authCubit.close();
    widget.apiClient.close();
    if (widget.firebaseNotifications != null) {
      unawaited(widget.firebaseNotifications!.dispose());
    }
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
        child: BlocListener<AuthCubit, AuthState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (_, state) {
            if (state.status == AuthStatus.authenticated &&
                widget.firebaseNotifications != null) {
              unawaited(widget.firebaseNotifications!.start());
            }
          },
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
      ),
    );
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) {
      return;
    }
    final context = _appRouter.navigatorKey.currentContext;
    if (context == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notification.title ?? notification.body ?? 'New update'),
        action: SnackBarAction(
            label: 'View', onPressed: () => _openNotification(message)),
      ),
    );
  }

  void _openNotification(RemoteMessage message) {
    final targetType = message.data['targetType'];
    final targetId = message.data['targetId'];
    if (targetType is! String || targetId is! String || targetId.isEmpty) {
      return;
    }
    _appRouter.router.go(
      Uri(
        path: AppRoutes.requests,
        queryParameters: {'targetType': targetType, 'targetId': targetId},
      ).toString(),
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
