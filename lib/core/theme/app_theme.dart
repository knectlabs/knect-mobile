import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF176B52);
  static const _lightSurface = Color(0xFFF7F5EF);
  static const _darkSurface = Color(0xFF111714);

  static ThemeData get light => _build(
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
          surface: _lightSurface,
        ),
      );

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
          surface: _darkSurface,
        ),
      );

  static ThemeData _build(ColorScheme colors) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
