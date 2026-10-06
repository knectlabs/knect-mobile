import 'package:flutter/material.dart';

abstract final class KnectColors {
  static const lightPurple = Color(0xFFAB9AFA);
  static const lilac = Color(0xFFD8CEFC);
  static const background = Color(0xFFF8F7FC);
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF7D5CF5);
  static const strongPrimary = Color(0xFF583CCD);
  static const textPrimary = Color(0xFF19152B);
  static const textSecondary = Color(0xFF6B7280);
  static const mutedText = Color(0xFF606978);
  static const border = Color(0xFFE9E5F5);
  static const lilacSurface = Color(0xFFEFE8FC);
  static const success = Color(0xFF166534);
  static const successSurface = Color(0xFFDCFCE7);
  static const warning = Color(0xFF854D0E);
  static const warningSurface = Color(0xFFFEF3C7);
  static const danger = Color(0xFFB91C1C);
  static const dangerSurface = Color(0xFFFEE2E2);
  static const cameraBackdrop = Color(0xFF111827);
}

abstract final class KnectSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 32.0;
  static const page = EdgeInsets.all(xl);
}

abstract final class KnectRadius {
  static const field = 12.0;
  static const card = 16.0;
  static const sheet = 24.0;
  static const pill = 99.0;
}

abstract final class KnectTypography {
  static const fontFamily = 'Roboto';
  static const textTheme = TextTheme(
    headlineLarge:
        TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.2),
    headlineMedium:
        TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
    headlineSmall:
        TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
    titleLarge:
        TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium:
        TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall:
        TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, height: 1.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    labelMedium:
        TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
  );
}
