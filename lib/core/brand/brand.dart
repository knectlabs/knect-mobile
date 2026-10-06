import '../theme/knect_tokens.dart';

/// Customer-facing Knect brand.
abstract final class Brand {
  static const name = 'Knect';

  static const iconAsset = 'assets/brand/knect_icon.png';
  static const wordmarkAsset = 'assets/brand/knect_wordmark.png';
}

/// Compatibility names for existing screens; values come from the shared tokens.
abstract final class BrandColors {
  static const primaryViolet = KnectColors.primary;
  static const secondaryViolet = KnectColors.strongPrimary;
  static const deepViolet = KnectColors.strongPrimary;
  static const darkPurple = KnectColors.textPrimary;
  static const darkestPurple = KnectColors.textPrimary;
  static const ink = KnectColors.textPrimary;
  static const softLilac = KnectColors.lilac;
  static const lightLilac = KnectColors.lilacSurface;
  static const offWhite = KnectColors.background;
}
