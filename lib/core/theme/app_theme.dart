import 'package:flutter/material.dart';

import '../brand/brand.dart';

abstract final class AppTheme {
  static const _lightSurface = Color(0xFFF8F7FC);
  static const _darkSurface = Color(0xFF0F0B1E);

  static ThemeData get light => _build(
        ColorScheme.fromSeed(
          seedColor: BrandColors.primaryViolet,
          brightness: Brightness.light,
          surface: _lightSurface,
        ).copyWith(
          // #583CCD keeps white button text above 4.5:1; #7D5CF5 does not.
          primary: BrandColors.secondaryViolet,
          onPrimary: Colors.white,
          primaryContainer: BrandColors.lightLilac,
          onPrimaryContainer: BrandColors.darkPurple,
          onSurface: BrandColors.ink,
        ),
      );

  static ThemeData get dark => _build(
        ColorScheme.fromSeed(
          seedColor: BrandColors.primaryViolet,
          brightness: Brightness.dark,
          surface: _darkSurface,
        ).copyWith(
          primary: BrandColors.softLilac,
          onPrimary: BrandColors.darkPurple,
          primaryContainer: BrandColors.deepViolet,
          onPrimaryContainer: BrandColors.offWhite,
        ),
      );

  static ThemeData _build(ColorScheme colors) {
    final radius = BorderRadius.circular(12);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );

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
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: border(colors.outlineVariant),
        enabledBorder: border(colors.outlineVariant),
        focusedBorder: border(colors.primary, 2),
        errorBorder: border(colors.error),
        focusedErrorBorder: border(colors.error, 2),
        disabledBorder: border(colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
    );
  }
}
