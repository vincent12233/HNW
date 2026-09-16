import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Minimal elevation system — prefer surface + border over heavy shadows.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> small = [
    BoxShadow(color: Color(0x0A102A56), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(color: Color(0x14102A56), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static const List<BoxShadow> brandHero = [
    BoxShadow(color: Color(0x262558D9), blurRadius: 16, offset: Offset(0, 6)),
  ];

  static Color dialogShadowColor = AppColors.brandDark.withValues(alpha: 0.2);
}
