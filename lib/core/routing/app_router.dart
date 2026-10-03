import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
}

class AppRouter {
  AppRouter(AuthCubit authCubit) {
    _refresh = _RouterRefresh(authCubit.stream);
    router = GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: _refresh,
      redirect: (context, state) {
        final status = authCubit.state.status;
        final isLoginRoute = state.matchedLocation == AppRoutes.login;

        if (status != AuthStatus.authenticated && !isLoginRoute) {
          return AppRoutes.login;
        }
        if (status == AuthStatus.authenticated && isLoginRoute) {
          return AppRoutes.home;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomeScreen(),
        ),
      ],
    );
  }

  late final _RouterRefresh _refresh;
  late final GoRouter router;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
