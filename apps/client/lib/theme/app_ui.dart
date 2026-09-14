import 'package:flutter/material.dart';

import '../app_config.dart';

/// Shared visual tokens for consistent spacing, radii and surfaces.
/// Does not change navigation or business behavior.
class AppUi {
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double pagePadding = 16;
  static const double sectionGap = 18;
  static const double cardPadding = 16;

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);

  static BoxDecoration surface({
    Color color = Colors.white,
    double radius = radiusMd,
    bool bordered = true,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: bordered ? Border.all(color: AppConfig.borderColor) : null,
      boxShadow: shadows ??
          const [
            BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
    );
  }

  static BoxDecoration heroGradient({double radius = radiusLg}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppConfig.primaryDarkColor,
          AppConfig.primaryGradientEnd,
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33165DFF),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppConfig.textPrimaryColor,
    letterSpacing: -0.2,
  );

  static const TextStyle cardLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppConfig.textSecondaryColor,
  );

  static const TextStyle heroValue = TextStyle(
    color: Colors.white,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.1,
  );
}
