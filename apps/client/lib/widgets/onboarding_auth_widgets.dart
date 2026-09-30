import '../l10n/app_language.dart';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';

InputDecoration onboardingInput(
  String label, {
  String? errorText,
  String? helperText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? prefixText,
}) => InputDecoration(
  labelText: tr(label),
  floatingLabelBehavior: FloatingLabelBehavior.always,
  errorText: errorText,
  errorMaxLines: 4,
  helperText: helperText,
  helperMaxLines: 3,
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  prefixText: prefixText,
  filled: true,
  fillColor: AuthLayout.pageBackground,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  border: OutlineInputBorder(borderRadius: AppRadius.borderSm),
  enabledBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderSm,
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderSm,
    borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderSm,
    borderSide: const BorderSide(color: AppColors.loss),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderSm,
    borderSide: const BorderSide(color: AppColors.loss, width: 1.5),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderSm,
    borderSide: const BorderSide(color: AppColors.border),
  ),
);

class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key, this.showSlogan = true});

  final bool showSlogan;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('HNW', style: AuthLayout.wordmark),
      if (showSlogan) ...[
        const SizedBox(height: 4),
        Text(
          AppConfig.slogan,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: AuthLayout.helperSize,
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            height: 1.3,
          ),
        ),
      ],
    ],
  );
}

/// A small, low-distraction motion cue that gives auth screens a live brand
/// presence without competing with the form or moving its layout.
class AnimatedAuthBrandHeader extends StatefulWidget {
  const AnimatedAuthBrandHeader({super.key, this.showSlogan = true});

  final bool showSlogan;

  @override
  State<AnimatedAuthBrandHeader> createState() =>
      _AnimatedAuthBrandHeaderState();
}

class _AnimatedAuthBrandHeaderState extends State<AnimatedAuthBrandHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;
    if (!AppMotion.reduce(context)) {
      // A finite entrance pulse keeps pumpAndSettle and reduced-motion users
      // deterministic while still giving the auth screen a live first frame.
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final progress = Curves.easeInOut.transform(_controller.value);
      final pulse = 1 - (2 * progress - 1).abs();
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderSm,
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withValues(
                alpha: 0.08 + pulse * 0.1,
              ),
              blurRadius: 18 + pulse * 8,
              spreadRadius: pulse * 1.5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: child,
        ),
      );
    },
    child: AuthBrandHeader(showSlogan: widget.showSlogan),
  );
}

class FinvestWordmark extends StatelessWidget {
  const FinvestWordmark({super.key});

  @override
  Widget build(BuildContext context) => const AuthBrandHeader();
}

class AuthFormError extends StatelessWidget {
  const AuthFormError({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();
    return AppStatusSwitch(
      switchKey: message,
      duration: AppMotion.micro,
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lossSoft,
            borderRadius: AppRadius.borderSm,
            border: Border.all(color: AppColors.loss.withValues(alpha: 0.35)),
          ),
          child: AppText(
            message,
            style: const TextStyle(
              color: AppColors.loss,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthNoticeBanner extends StatelessWidget {
  const AuthNoticeBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: AppText(
          message,
          style: const TextStyle(
            color: AppColors.warning,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.succeeded = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool succeeded;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final inFlight = busy || succeeded;
    return SizedBox(
      height: AuthLayout.buttonHeight,
      width: double.infinity,
      child: FilledButton(
        onPressed: inFlight || !enabled ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AuthLayout.buttonHeight),
          maximumSize: const Size.fromHeight(AuthLayout.buttonHeight),
          padding: EdgeInsets.zero,
          disabledBackgroundColor: inFlight
              ? AppColors.brandPrimary
              : AppColors.disabled,
          disabledForegroundColor: inFlight
              ? AppColors.textInverse
              : AppColors.textDisabled,
          overlayColor: AppColors.brandPrimaryPressed.withValues(alpha: 0.18),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              duration: AppMotion.duration(context, AppMotion.micro),
              opacity: inFlight ? 0 : 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppMotion.iconField,
                      color: AppColors.textInverse,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        color: AppColors.textInverse,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (succeeded)
              const Icon(
                Icons.check_rounded,
                key: ValueKey('auth-success'),
                size: 20,
                color: AppColors.textInverse,
              )
            else if (busy)
              const SizedBox(
                key: ValueKey('auth-loading'),
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textInverse,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({super.key, required this.child, this.appBar});

  final Widget child;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = AuthLayout.formMaxWidth(media.size.width);
    final insets = AuthLayout.pageInsets(context);

    return Scaffold(
      backgroundColor: AuthLayout.pageBackground,
      resizeToAvoidBottomInset: true,
      appBar: appBar,
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: AppColors.brandPrimary,
              child: SizedBox(height: 3),
            ),
          ),
          SafeArea(
            top: appBar == null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        padding: insets,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - insets.vertical)
                                .clamp(0, double.infinity),
                          ),
                          child: AuthOutgoingShift(child: child),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AuthFocusGlow extends StatefulWidget {
  const AuthFocusGlow({super.key, required this.child});

  final Widget child;

  @override
  State<AuthFocusGlow> createState() => _AuthFocusGlowState();
}

class _AuthFocusGlowState extends State<AuthFocusGlow> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduce(context);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (value) {
        if (_focused == value) return;
        setState(() => _focused = value);
      },
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.micro),
        curve: AppMotion.ease,
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderSm,
          boxShadow: _focused && !reduce
              ? [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : const [],
        ),
        child: widget.child,
      ),
    );
  }
}

class AuthErrorShake extends StatefulWidget {
  const AuthErrorShake({
    super.key,
    required this.errorText,
    required this.child,
  });

  final String? errorText;
  final Widget child;

  @override
  State<AuthErrorShake> createState() => _AuthErrorShakeState();
}

class _AuthErrorShakeState extends State<AuthErrorShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _playedFor;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.micro);
    if (_hasError(widget.errorText)) {
      _playedFor = widget.errorText;
    }
  }

  @override
  void didUpdateWidget(AuthErrorShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasError(widget.errorText)) {
      _playedFor = null;
      return;
    }
    if (widget.errorText == _playedFor) return;
    _playedFor = widget.errorText;
    if (!AppMotion.reduce(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _hasError(String? value) => value != null && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final dx = t == 0 || t == 1 ? 0.0 : 3 * (1 - t) * (t < 0.5 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

class AuthPasswordToggle extends StatelessWidget {
  const AuthPasswordToggle({
    super.key,
    required this.obscure,
    required this.onPressed,
  });

  final bool obscure;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppMotion.tapTarget,
      height: AppMotion.tapTarget,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: AppMotion.tapTarget,
          minHeight: AppMotion.tapTarget,
        ),
        tooltip: obscure ? 'Show password' : 'Hide password',
        onPressed: onPressed,
        icon: AppStatusSwitch(
          switchKey: obscure,
          duration: AppMotion.micro,
          child: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: AuthLayout.passwordIconSize,
            semanticLabel: obscure ? 'Show password' : 'Hide password',
          ),
        ),
      ),
    );
  }
}

class AuthTextActionRow extends StatelessWidget {
  const AuthTextActionRow({
    super.key,
    required this.prompt,
    required this.actionLabel,
    required this.onPressed,
  });

  final String prompt;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppText(
          prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            letterSpacing: 0,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: onPressed,
          child: AppText(
            actionLabel,
            style: const TextStyle(fontSize: 13, letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}

class SecureFooter extends StatelessWidget {
  const SecureFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.lock_outline,
            size: 14,
            color: AppColors.textTertiary,
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: AppText(
            'Sign in with your registered mobile number and password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: AuthLayout.helperSize,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
