import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Screen-adaptive metrics for the Customer Service FAB and chat panel.
///
/// Tuned against a ~390×844 reference phone and scaled for small / tall /
/// tablet-class layouts.
class SupportUiMetrics {
  const SupportUiMetrics({
    required this.scale,
    required this.fabWidth,
    required this.fabHeight,
    required this.fabBottom,
    required this.fabRadius,
    required this.fabFontSize,
    required this.fabIconSize,
    required this.panelWidth,
    required this.panelMaxHeight,
    required this.panelHorizontalInset,
    required this.panelBottomInset,
    required this.panelRadius,
    required this.contentPadding,
    required this.headerPadding,
    required this.titleSize,
    required this.subtitleSize,
    required this.bodySize,
    required this.chipFontSize,
    required this.avatarSize,
    required this.sendButtonSize,
    required this.composerHeight,
  });

  final double scale;
  final double fabWidth;
  final double fabHeight;
  final double fabBottom;
  final double fabRadius;
  final double fabFontSize;
  final double fabIconSize;
  final double panelWidth;
  final double panelMaxHeight;
  final double panelHorizontalInset;
  final double panelBottomInset;
  final double panelRadius;
  final double contentPadding;
  final double headerPadding;
  final double titleSize;
  final double subtitleSize;
  final double bodySize;
  final double chipFontSize;
  final double avatarSize;
  final double sendButtonSize;
  final double composerHeight;

  factory SupportUiMetrics.of(BuildContext context) {
    final media = MediaQuery.of(context);
    return SupportUiMetrics.fromView(
      size: media.size,
      padding: media.padding,
      viewInsets: media.viewInsets,
      textScale: media.textScaler.scale(1),
    );
  }

  factory SupportUiMetrics.fromView({
    required Size size,
    required EdgeInsets padding,
    EdgeInsets viewInsets = EdgeInsets.zero,
    double textScale = 1,
  }) {
    final width = size.width;
    final height = size.height;
    final shortest = size.shortestSide;
    // Reference phone used for the Customer Service tab design.
    final scale = (shortest / 390).clamp(0.82, 1.22);
    final textAware = scale * textScale.clamp(1.0, 1.2);

    final smallWidth = width < 360;
    final shortHeight = height < 680;
    final largePhone = width >= 420 && height >= 850;
    final tablet = shortest >= 600;

    final fabWidth = (24 * scale).clamp(22.0, 30.0);
    final fabHeight = (height * (shortHeight ? 0.15 : 0.132)).clamp(
      shortHeight ? 92.0 : 100.0,
      largePhone ? 128.0 : 118.0,
    );
    // Sit above the bottom navigation bar on phones of different heights.
    final fabBottom = (height * 0.1).clamp(shortHeight ? 64.0 : 72.0, 96.0);

    final hInset = (width * (smallWidth ? 0.04 : 0.07)).clamp(
      smallWidth ? 10.0 : 14.0,
      tablet ? 40.0 : 28.0,
    );
    // Clear bottom nav (~56–80) + home indicator.
    final bottomInset =
        padding.bottom +
        viewInsets.bottom +
        (height * 0.09).clamp(shortHeight ? 56.0 : 64.0, 92.0);

    final usableHeight = math.max(240.0, height - padding.top - bottomInset);
    final heightFraction = shortHeight
        ? 0.84
        : (largePhone ? 0.64 : (tablet ? 0.58 : 0.70));

    final availableWidth = math.max(0.0, width - hInset * 2);
    final preferredMaxWidth = tablet
        ? 420.0
        : (largePhone ? 360.0 : (smallWidth ? availableWidth : 320.0));
    final panelWidth = math.min(availableWidth, preferredMaxWidth);
    final panelMaxHeight = (usableHeight * heightFraction)
        .clamp(
          math.min(shortHeight ? 300.0 : 360.0, usableHeight),
          usableHeight,
        )
        .toDouble();

    return SupportUiMetrics(
      scale: scale,
      fabWidth: fabWidth,
      fabHeight: fabHeight,
      fabBottom: fabBottom,
      fabRadius: (7 * scale).clamp(6.0, 10.0),
      fabFontSize: (10 * textAware).clamp(9.0, 12.0),
      fabIconSize: (10 * scale).clamp(9.0, 13.0),
      panelWidth: panelWidth,
      panelMaxHeight: panelMaxHeight,
      panelHorizontalInset: hInset,
      panelBottomInset: bottomInset,
      panelRadius: (14 * scale).clamp(12.0, 18.0),
      contentPadding: (12 * scale).clamp(10.0, 16.0),
      headerPadding: (8 * scale).clamp(6.0, 12.0),
      titleSize: (13 * textAware).clamp(12.0, 16.0),
      subtitleSize: (10 * textAware).clamp(9.0, 12.0),
      bodySize: (13 * textAware).clamp(12.0, 15.0),
      chipFontSize: (11 * textAware).clamp(10.0, 13.0),
      avatarSize: (32 * scale).clamp(28.0, 40.0),
      sendButtonSize: (40 * scale).clamp(36.0, 48.0),
      composerHeight: (40 * scale).clamp(36.0, 48.0),
    );
  }
}
