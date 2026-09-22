import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Spacing and type tokens for authentication screens.
///
/// Values are inferred from the supplied 8-up login/register reference
/// (source 1024×340, each device ~118px wide) scaled to a 390×844 logical
/// viewport. Exact native-pixel overlays are limited by that source
/// resolution; these are the nearest operable estimates.
abstract final class AuthLayout {
  static const Size referenceViewport = Size(390, 844);

  static const double pagePaddingH = 24;
  static const double compactPaddingH = 16;
  static const double pagePaddingTop = 16;
  static const double pagePaddingBottom = 24;
  static const double maxFormWidth = 400;
  static const double fieldGap = 16;
  static const double sectionGap = 28;
  static const double titleGap = 6;
  static const double inputHeight = 52;
  static const double buttonHeight = 48;
  static const double iconSize = 20;
  static const double passwordIconSize = 18;
  static const double logoSize = 28;
  static const double titleSize = 28;
  static const double titleLineHeight = 1.2;
  static const double subtitleSize = 13;
  static const double bodySize = 14;
  static const double helperSize = 12;
  static const double radius = 8;

  static const Color pageBackground = Color(0xFFFFFFFF);

  static double horizontalPadding(double width) {
    if (width < 360) return compactPaddingH;
    if (width >= 1024) return 32;
    return pagePaddingH;
  }

  static double formMaxWidth(double width) {
    if (width >= 768) return maxFormWidth;
    return width;
  }

  static EdgeInsets pageInsets(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compactHeight = size.height < 640;
    return EdgeInsets.fromLTRB(
      horizontalPadding(size.width),
      compactHeight ? 12 : pagePaddingTop,
      horizontalPadding(size.width),
      compactHeight ? 16 : pagePaddingBottom,
    );
  }

  static const TextStyle wordmark = TextStyle(
    fontSize: logoSize,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: 0,
    color: AppColors.brandPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: titleSize,
    fontWeight: FontWeight.w700,
    height: titleLineHeight,
    letterSpacing: 0,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: subtitleSize,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.textSecondary,
  );
}
