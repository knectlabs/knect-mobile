import 'package:flutter/painting.dart';

/// Customer-facing Knect brand.
abstract final class Brand {
  static const name = 'Knect';

  static const iconAsset = 'assets/brand/knect_icon.png';
  static const wordmarkAsset = 'assets/brand/knect_wordmark.png';
}

/// Knect palette, taken from the app icon and wordmark.
abstract final class BrandColors {
  static const primaryViolet = Color(0xFF7D5CF5);
  static const secondaryViolet = Color(0xFF583CCD);
  static const deepViolet = Color(0xFF3C249A);
  static const darkPurple = Color(0xFF1E1150);
  static const darkestPurple = Color(0xFF130A35);

  static const ink = Color(0xFF19152B);
  static const softLilac = Color(0xFFAB9AFA);
  static const lightLilac = Color(0xFFD8CEFC);
  static const offWhite = Color(0xFFEFE8FC);

  /// Brand surfaces (sign-in band, splash) use the icon's background gradient.
  static const brandGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [darkestPurple, darkPurple, deepViolet],
    stops: [0, 0.55, 1],
  );
}
