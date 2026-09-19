import 'package:flutter/material.dart';

/// Short, professional motion tokens for KYC and onboarding UI.
///
/// Durations stay in the 120–300ms range. Callers must not use these
/// tokens to imply verification, OCR, liveness, or bank confirmation.
abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 240);
  static const Curve ease = Curves.easeOut;

  static const double iconInline = 18;
  static const double iconField = 20;
  static const double iconToolbar = 24;
  static const double iconStep = 22;
  static const double iconEmpty = 48;
  static const double tapTarget = 44;

  static bool reduce(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.disableAnimations || media.accessibleNavigation;
  }

  static Duration duration(BuildContext context, Duration normal) =>
      reduce(context) ? Duration.zero : normal;
}

class KycFadeIn extends StatelessWidget {
  const KycFadeIn({super.key, required this.switchKey, required this.child});

  final Object switchKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduce(context);
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppMotion.page),
      switchInCurve: AppMotion.ease,
      switchOutCurve: AppMotion.ease,
      layoutBuilder: (currentChild, previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) {
        if (reduce) return child;
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
  }
}

class KycStatusSwitch extends StatelessWidget {
  const KycStatusSwitch({
    super.key,
    required this.switchKey,
    required this.child,
    this.duration = AppMotion.state,
  });

  final Object switchKey;
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduce(context);
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, duration),
      switchInCurve: AppMotion.ease,
      switchOutCurve: AppMotion.ease,
      layoutBuilder: (currentChild, previousChildren) =>
          currentChild ?? const SizedBox.shrink(),
      transitionBuilder: (child, animation) {
        if (reduce) return child;
        return FadeTransition(opacity: animation, child: child);
      },
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
  }
}
