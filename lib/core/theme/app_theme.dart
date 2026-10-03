import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFF176B52);
  static const _lightSurface = Color(0xFFF7F5EF);
  static const _darkSurface = Color(0xFF111714);

  /// Brand surfaces (logo band, splash) stay deep green in both themes and
  /// match the admin web `--brand` token.
  static const brand = Color(0xFF176B52);
  static const brandDark = Color(0xFF0F4A39);
  static const onBrand = Color(0xFFF6FBF8);

  static Color brandFor(Brightness brightness) =>
      brightness == Brightness.dark ? brandDark : brand;

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
