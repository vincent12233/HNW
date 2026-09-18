import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
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
      const Text('HNW', style: AuthLayout.wordmark),
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
    return Semantics(
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
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AuthLayout.buttonHeight,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy || !enabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AuthLayout.buttonHeight),
        maximumSize: const Size.fromHeight(AuthLayout.buttonHeight),
        padding: EdgeInsets.zero,
        disabledBackgroundColor: busy
            ? AppColors.brandPrimary
            : AppColors.disabled,
        disabledForegroundColor: busy
            ? AppColors.textInverse
            : AppColors.textDisabled,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: busy ? 0 : 1,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: AppColors.textInverse,
              ),
            ),
          ),
          if (busy)
            const SizedBox(
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

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.child,
    this.appBar,
  });

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
      body: SafeArea(
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
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class SecureFooter extends StatelessWidget {
  const SecureFooter({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 20),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 14, color: AppColors.textTertiary),
        SizedBox(width: 6),
        Flexible(
          child: AppText(
            'Sign in with your registered Indian mobile number and password.',
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

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.verified_user,
  });
  final String title, subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.warningSoft,
      borderRadius: AppRadius.borderSm,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.warning, size: AuthLayout.iconSize),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AuthLayout.helperSize,
                  height: 1.35,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
