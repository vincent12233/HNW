import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Shared visual tokens and surface helpers for the HNW design system.
///
/// Does not change navigation or business behavior.
abstract final class AppUi {
  // Spacing (legacy aliases + full scale)
  static const double pagePadding = AppSpacing.pagePadding;
  static const double sectionGap = AppSpacing.sectionGap;
  static const double cardPadding = AppSpacing.cardPadding;

  // Radius (legacy aliases)
  static const double radiusSm = AppRadius.sm;
  static const double radiusMd = AppRadius.md;
  static const double radiusLg = AppRadius.lg;

  static BorderRadius get borderRadiusSm => AppRadius.borderSm;
  static BorderRadius get borderRadiusMd => AppRadius.borderMd;
  static BorderRadius get borderRadiusLg => AppRadius.borderLg;

  static const TextStyle sectionTitle = AppTypography.sectionTitle;
  static const TextStyle cardLabel = AppTypography.cardLabel;
  static const TextStyle heroValue = AppTypography.numericInverse;

  static BoxDecoration surface({
    Color color = AppColors.surface,
    double radius = AppRadius.md,
    bool bordered = true,
    Color? borderColor,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: bordered
          ? Border.all(color: borderColor ?? AppColors.border)
          : null,
      boxShadow: shadows ?? AppShadows.none,
    );
  }

  static BoxDecoration elevatedSurface({
    Color color = AppColors.surfaceElevated,
    double radius = AppRadius.md,
  }) {
    return surface(
      color: color,
      radius: radius,
      bordered: true,
      shadows: AppShadows.small,
    );
  }

  static BoxDecoration heroGradient({double radius = AppRadius.lg}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.brandDark, AppColors.brandGradientEnd],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: AppShadows.brandHero,
    );
  }

  static Color gainLossColor(double value, {bool zeroIsNeutral = true}) {
    if (zeroIsNeutral && value == 0) return AppColors.textSecondary;
    return value >= 0 ? AppColors.gain : AppColors.loss;
  }

  static Color gainLossSoftColor(double value, {bool zeroIsNeutral = true}) {
    if (zeroIsNeutral && value == 0) return AppColors.neutralSoft;
    return value >= 0 ? AppColors.gainSoft : AppColors.lossSoft;
  }
}
