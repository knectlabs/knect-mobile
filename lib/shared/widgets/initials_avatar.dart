import 'package:flutter/material.dart';

import '../../core/brand/brand.dart';

/// Circle with up to two initials, for people without a photo.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    this.radius = 24,
    this.onBrand = false,
    super.key,
  });

  final String name;
  final double radius;

  /// White ring for use on the brand header.
  final bool onBrand;

  static String initialsOf(String name) => name
      .split(RegExp(r'[\s@.]'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: BrandColors.brandGradient,
        border: onBrand ? Border.all(color: Colors.white, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}
