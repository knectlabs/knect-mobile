import 'package:flutter/material.dart';

import '../../features/auth/domain/auth_models.dart';

/// Pushes a full-screen page above the tab bar.
Future<T?> pushPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true)
        .push<T>(MaterialPageRoute(builder: (_) => page));

/// Roles that receive approval steps (direct reports or the HR pool).
bool canApprove(UserRole? role) => switch (role) {
      UserRole.manager ||
      UserRole.hr ||
      UserRole.companyAdmin ||
      UserRole.superAdmin =>
        true,
      _ => false,
    };
