import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'knect_tokens.dart';
export 'knect_tokens.dart';

abstract final class KnectTheme {
  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
            seedColor: KnectColors.primary, brightness: Brightness.light)
        .copyWith(
      primary: KnectColors.primary,
      onPrimary: KnectColors.surface,
      primaryContainer: KnectColors.lilacSurface,
      onPrimaryContainer: KnectColors.strongPrimary,
      secondary: KnectColors.strongPrimary,
      onSecondary: KnectColors.surface,
      secondaryContainer: KnectColors.lilacSurface,
      onSecondaryContainer: KnectColors.textPrimary,
      surface: KnectColors.surface,
      onSurface: KnectColors.textPrimary,
      onSurfaceVariant: KnectColors.mutedText,
      surfaceContainerLowest: KnectColors.surface,
      surfaceContainerLow: KnectColors.background,
      surfaceContainer: KnectColors.background,
      surfaceContainerHigh: KnectColors.lilacSurface,
      surfaceContainerHighest: KnectColors.lilacSurface,
      outline: KnectColors.textSecondary,
      outlineVariant: KnectColors.border,
      error: KnectColors.danger,
      errorContainer: KnectColors.dangerSurface,
      onErrorContainer: KnectColors.danger,
      surfaceTint: Colors.transparent,
    );
    final radius = BorderRadius.circular(KnectRadius.field);
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: color, width: width));
    return ThemeData(
      useMaterial3: true,
      fontFamily: KnectTypography.fontFamily, colorScheme: colors,
      scaffoldBackgroundColor: KnectColors.background,
      textTheme: KnectTypography.textTheme.apply(
          bodyColor: KnectColors.textPrimary,
          displayColor: KnectColors.textPrimary),
      iconTheme:
          const IconThemeData(size: 24, color: KnectColors.strongPrimary),
      appBarTheme: const AppBarTheme(
          backgroundColor: KnectColors.background,
          foregroundColor: KnectColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              color: KnectColors.textPrimary,
              fontFamily: KnectTypography.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w700),
          systemOverlayStyle: SystemUiOverlayStyle.dark),
      dividerTheme: const DividerThemeData(
          color: KnectColors.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: KnectColors.surface,
          labelStyle: const TextStyle(color: KnectColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: KnectSpacing.lg, vertical: KnectSpacing.lg),
          border: border(KnectColors.border),
          enabledBorder: border(KnectColors.border),
          focusedBorder: border(KnectColors.strongPrimary, 2),
          errorBorder: border(KnectColors.danger),
          focusedErrorBorder: border(KnectColors.danger, 2),
          disabledBorder: border(KnectColors.border)),
      // Strong primary keeps white action labels above 4.5:1 contrast.
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: KnectColors.strongPrimary,
              foregroundColor: KnectColors.surface,
              minimumSize: const Size(48, 52),
              textStyle: const TextStyle(
                  fontFamily: KnectTypography.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: radius))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: KnectColors.strongPrimary,
              foregroundColor: KnectColors.surface,
              minimumSize: const Size(48, 52),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: radius))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              foregroundColor: KnectColors.strongPrimary,
              minimumSize: const Size(48, 48),
              side: const BorderSide(color: KnectColors.lilac),
              shape: RoundedRectangleBorder(borderRadius: radius))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: KnectColors.strongPrimary,
              minimumSize: const Size(48, 48))),
      cardTheme: CardThemeData(
          elevation: 0,
          color: KnectColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KnectRadius.card),
              side: const BorderSide(color: KnectColors.border))),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: KnectColors.surface,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          dragHandleColor: KnectColors.lilac,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(KnectRadius.sheet)))),
      dialogTheme: DialogThemeData(
          backgroundColor: KnectColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KnectRadius.sheet))),
      tabBarTheme: const TabBarThemeData(
          labelColor: KnectColors.strongPrimary,
          unselectedLabelColor: KnectColors.textSecondary,
          indicatorColor: KnectColors.strongPrimary,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: KnectColors.border,
          labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
              backgroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? KnectColors.lilacSurface
                      : KnectColors.surface),
              foregroundColor: WidgetStateProperty.resolveWith((states) =>
                  states.contains(WidgetState.selected)
                      ? KnectColors.strongPrimary
                      : KnectColors.textSecondary),
              side: const WidgetStatePropertyAll(
                  BorderSide(color: KnectColors.border)))),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: KnectColors.surface,
          surfaceTintColor: Colors.transparent,
          indicatorColor: KnectColors.lilacSurface,
          elevation: 0,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? KnectColors.strongPrimary
                  : KnectColors.textSecondary)),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? KnectColors.strongPrimary
                  : KnectColors.textSecondary))),
      listTileTheme: const ListTileThemeData(
          iconColor: KnectColors.strongPrimary,
          textColor: KnectColors.textPrimary,
          minVerticalPadding: 12,
          contentPadding: EdgeInsets.symmetric(horizontal: KnectSpacing.xl)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: KnectColors.strongPrimary,
          foregroundColor: KnectColors.surface,
          elevation: 0),
      chipTheme: ChipThemeData(
          backgroundColor: KnectColors.lilacSurface,
          labelStyle: const TextStyle(
              fontFamily: KnectTypography.fontFamily,
              color: KnectColors.strongPrimary),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(KnectRadius.pill))),
      snackBarTheme: const SnackBarThemeData(
          backgroundColor: KnectColors.textPrimary,
          behavior: SnackBarBehavior.floating),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => KnectTheme.light;
}
