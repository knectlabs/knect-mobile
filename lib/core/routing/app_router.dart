import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_cubit.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/employee/presentation/employees_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/inbox/presentation/inbox_screen.dart';
import '../../features/notifications/data/notifications_repository.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/requests/presentation/requests_screen.dart';
import '../../features/requests/data/requests_repository.dart';

abstract final class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const employees = '/employees';
  static const requests = '/requests';
  static const inbox = '/inbox';
  static const account = '/account';
}

class AppRouter {
  AppRouter(AuthCubit authCubit) {
    _refresh = _RouterRefresh(authCubit.stream);
    router = GoRouter(
      initialLocation: AppRoutes.home,
      navigatorKey: navigatorKey,
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
        // Tabs follow the Talenta-style layout the product owner chose
        // (2026-10-04): attendance lives on Home; Payroll joins the Home apps.
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _TabShell(shell: shell),
          branches: [
            for (final (path, screen) in const [
              (AppRoutes.home, HomeScreen()),
              (AppRoutes.employees, EmployeesScreen()),
              (AppRoutes.requests, RequestsScreen()),
              (AppRoutes.inbox, InboxScreen()),
              (AppRoutes.account, ProfileScreen()),
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: path,
                    builder: (_, state) => path == AppRoutes.requests
                        ? RequestsScreen(target: _requestTarget(state))
                        : screen,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  late final _RouterRefresh _refresh;
  final navigatorKey = GlobalKey<NavigatorState>();
  late final GoRouter router;

  void dispose() {
    router.dispose();
    _refresh.dispose();
  }
}

RequestTarget? _requestTarget(GoRouterState state) {
  final type = state.uri.queryParameters['targetType'];
  final id = state.uri.queryParameters['targetId'];
  if (type == null || id == null || id.isEmpty) return null;
  return RequestTarget(type: type, id: id);
}

class _TabShell extends StatelessWidget {
  const _TabShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UnreadCountCubit>().state;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) {
          if (index == 3) context.read<UnreadCountCubit>().refresh();
          shell.goBranch(index, initialLocation: index == shell.currentIndex);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Employees',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Request',
          ),
          NavigationDestination(
            key: const Key('nav.inbox'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.mail_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.mail),
            ),
            label: 'Inbox',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
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
