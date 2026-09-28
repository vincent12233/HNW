import 'package:flutter/widgets.dart';

import '../theme/app_breakpoints.dart';

@immutable
class AppResponsive {
  const AppResponsive({required this.size, required this.textScale});

  factory AppResponsive.of(BuildContext context) => AppResponsive(
    size: MediaQuery.sizeOf(context),
    textScale: MediaQuery.textScalerOf(context).scale(1),
  );

  final Size size;
  final double textScale;

  AppWindowClass get windowClass => appWindowClass(size.width);
  bool get isCompact => windowClass == AppWindowClass.compact;
  bool get isMedium => windowClass == AppWindowClass.medium;
  bool get isExpanded =>
      windowClass == AppWindowClass.expanded ||
      windowClass == AppWindowClass.desktop;
  bool get isLandscape => size.width > size.height;
  bool get usesLargeText => textScale > 1.2;
}
