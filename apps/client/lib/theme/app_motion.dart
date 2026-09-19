import 'package:flutter/material.dart';

/// Short, professional motion tokens for KYC, authentication, and onboarding UI.
///
/// Durations stay in the 120–300ms range. Callers must not use these
/// tokens to imply verification, OCR, liveness, or bank confirmation.
abstract final class AppMotion {
  static const Duration micro = Duration(milliseconds: 150);
  static const Duration state = Duration(milliseconds: 200);
  static const Duration page = Duration(milliseconds: 240);
  static const Duration press = Duration(milliseconds: 100);
  static const Duration reduced = Duration(milliseconds: 100);
  static const Duration success = Duration(milliseconds: 180);
  static const Duration entrance = Duration(milliseconds: 620);
  static const Duration entranceRegister = Duration(milliseconds: 680);
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

class AppFadeIn extends StatelessWidget {
  const AppFadeIn({super.key, required this.switchKey, required this.child});

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

class AppStatusSwitch extends StatelessWidget {
  const AppStatusSwitch({
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

class KycFadeIn extends AppFadeIn {
  const KycFadeIn({super.key, required super.switchKey, required super.child});
}

class KycStatusSwitch extends AppStatusSwitch {
  const KycStatusSwitch({
    super.key,
    required super.switchKey,
    required super.child,
    super.duration,
  });
}

class AppEntranceScope extends StatefulWidget {
  const AppEntranceScope({
    super.key,
    required this.child,
    this.play = true,
    this.total = AppMotion.entrance,
  });

  final Widget child;
  final bool play;
  final Duration total;

  static Animation<double>? animationOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_AppEntranceInherit>()
      ?.animation;

  static Duration totalOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AppEntranceInherit>()
          ?.total ??
      AppMotion.entrance;

  @override
  State<AppEntranceScope> createState() => _AppEntranceScopeState();
}

class _AppEntranceScopeState extends State<AppEntranceScope>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = AppMotion.reduce(context);
    if (!widget.play || reduce) {
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppEntranceInherit(
      animation: _controller,
      total: _controller.duration ?? widget.total,
      child: widget.child,
    );
  }
}

class _AppEntranceInherit extends InheritedWidget {
  const _AppEntranceInherit({
    required this.animation,
    required this.total,
    required super.child,
  });

  final Animation<double> animation;
  final Duration total;

  @override
  bool updateShouldNotify(_AppEntranceInherit oldWidget) =>
      animation != oldWidget.animation || total != oldWidget.total;
}

class AppEntrance extends StatelessWidget {
  const AppEntrance({
    super.key,
    required this.delay,
    required this.child,
    this.span = const Duration(milliseconds: 220),
    this.offsetY = 8,
  });

  final Duration delay;
  final Duration span;
  final double offsetY;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = AppEntranceScope.animationOf(context);
    if (parent == null) return child;
    final reduce = AppMotion.reduce(context);
    final totalMs = AppEntranceScope.totalOf(
      context,
    ).inMilliseconds.clamp(1, 100000).toDouble();
    final start = reduce
        ? 0.0
        : (delay.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final end = reduce
        ? 1.0
        : ((delay.inMilliseconds + span.inMilliseconds) / totalMs).clamp(
            start + 0.01,
            1.0,
          );
    final animation = CurvedAnimation(
      parent: parent,
      curve: Interval(start, end, curve: AppMotion.ease),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        return Opacity(
          opacity: t.clamp(0.05, 1.0),
          child: Transform.translate(
            offset: Offset(0, reduce ? 0 : offsetY * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AuthOutgoingShift extends StatelessWidget {
  const AuthOutgoingShift({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.secondaryAnimation;
    if (animation == null) return child;
    final reduce = AppMotion.reduce(context);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        if (t <= 0) return child!;
        return Opacity(
          opacity: (1 - t).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(reduce ? 0 : -12 * t, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class AuthSlidePageRoute<T> extends PageRouteBuilder<T> {
  AuthSlidePageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: AppMotion.page,
        reverseTransitionDuration: AppMotion.page,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final reduce = AppMotion.reduce(context);
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.ease,
          );
          if (reduce) {
            return FadeTransition(opacity: curved, child: child);
          }
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

Future<void> authSuccessPause(BuildContext context) async {
  if (!context.mounted || AppMotion.reduce(context)) return;
  await Future<void>.delayed(AppMotion.success);
}
