/// Shared responsive breakpoints. Layout decisions should depend on available
/// constraints, not on a specific phone model or a design-canvas width.
abstract final class AppBreakpoints {
  static const double compact = 360;
  static const double medium = 600;
  static const double expanded = 840;
  static const double desktop = 1200;
}

enum AppWindowClass { compact, medium, expanded, desktop }

AppWindowClass appWindowClass(double width) {
  if (width < AppBreakpoints.medium) return AppWindowClass.compact;
  if (width < AppBreakpoints.expanded) return AppWindowClass.medium;
  if (width < AppBreakpoints.desktop) return AppWindowClass.expanded;
  return AppWindowClass.desktop;
}
