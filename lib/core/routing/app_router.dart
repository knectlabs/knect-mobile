import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/requests/presentation/requests_screen.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const attendance = '/attendance';
  static const requests = '/requests';
  static const profile = '/profile';
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
        // Employee tabs (08_MOBILE_UX_FLOWS.md). Payroll joins in Phase 2.
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _TabShell(shell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.attendance,
                  builder: (context, state) => const AttendanceScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.requests,
                  builder: (context, state) => const RequestsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.profile,
                  builder: (context, state) => const ProfileScreen(),
                ),
              ],
            ),
          ],
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

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) =>
            shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fingerprint),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
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
