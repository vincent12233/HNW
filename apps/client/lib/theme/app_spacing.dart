import 'package:flutter/material.dart';

/// Spacing scale for consistent layout rhythm.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  static const double pagePadding = lg;
  static const double sectionGap = xl;
  static const double cardPadding = lg;
  static const double inputPaddingH = md + 2; // 14
  static const double inputPaddingV = lg;
  static const double buttonHeight = 44;
  static const double buttonHeightCompact = 40;
  static const double buttonPaddingH = xl;
  static const double navHeight = 68;

  static const EdgeInsets page = EdgeInsets.all(pagePadding);
  static const EdgeInsets card = EdgeInsets.all(cardPadding);
  static const EdgeInsets dialog = EdgeInsets.symmetric(
    horizontal: xl - 2,
    vertical: xxl,
  );
}
