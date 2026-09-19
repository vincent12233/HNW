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

enum KycBannerTone { info, warning, success, danger }

enum KycStepUiState { notStarted, inProgress, completed }

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.verified_user,
    this.tone = KycBannerTone.warning,
  });
  final String title, subtitle;
  final IconData icon;
  final KycBannerTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, accent) = switch (tone) {
      KycBannerTone.success => (AppColors.successSoft, AppColors.success),
      KycBannerTone.danger => (AppColors.lossSoft, AppColors.loss),
      KycBannerTone.info => (AppColors.brandPrimarySoft, AppColors.brandPrimary),
      KycBannerTone.warning => (AppColors.warningSoft, AppColors.warning),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: AuthLayout.iconSize),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: AuthLayout.helperSize,
                    height: 1.4,
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
}

class KycProgressHeader extends StatelessWidget {
  const KycProgressHeader({
    super.key,
    required this.completed,
    this.total = 6,
  });

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          spacing: 12,
          children: [
            const AppText(
              'Verification Progress',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: AuthLayout.helperSize,
                letterSpacing: 0,
                color: AppColors.textPrimary,
              ),
            ),
            AppText(
              '$completed of $total completed',
              style: const TextStyle(
                fontSize: AuthLayout.helperSize,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: AppRadius.borderSm,
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: AppColors.brandPrimarySoft,
            color: AppColors.brandPrimary,
          ),
        ),
      ],
    );
  }
}

class KycStepTile extends StatelessWidget {
  const KycStepTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final KycStepUiState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (iconColor, ringColor, stateLabel, trailing, trailingColor) = switch (state) {
      KycStepUiState.completed => (
        AppColors.success,
        AppColors.successSoft,
        'Completed',
        Icons.check_circle,
        AppColors.success,
      ),
      KycStepUiState.inProgress => (
        AppColors.brandPrimary,
        AppColors.brandPrimarySoft,
        'In progress',
        Icons.chevron_right,
        AppColors.brandPrimary,
      ),
      KycStepUiState.notStarted => (
        AppColors.textSecondary,
        AppColors.surfaceSecondary,
        'Not started',
        Icons.chevron_right,
        AppColors.textTertiary,
      ),
    };

    return Material(
      color: AuthLayout.pageBackground,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ringColor,
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(icon, color: iconColor, size: AuthLayout.iconSize),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: const TextStyle(
                        fontSize: AuthLayout.bodySize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                        height: 1.35,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: AuthLayout.helperSize,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      stateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                        height: 1.3,
                        color: trailingColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(trailing, color: trailingColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
