import '../l10n/app_language.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/picked_bytes_file.dart';
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
                      child: AuthOutgoingShift(child: child),
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
      KycBannerTone.info => (
        AppColors.brandPrimarySoft,
        AppColors.brandPrimary,
      ),
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
          Icon(
            icon,
            color: accent,
            size: AuthLayout.iconSize,
            semanticLabel: title,
          ),
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
  const KycProgressHeader({super.key, required this.completed, this.total = 6});

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
    final (
      iconColor,
      ringColor,
      stateLabel,
      trailing,
      trailingColor,
    ) = switch (state) {
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
                child: Icon(icon, color: iconColor, size: AppMotion.iconStep),
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
              KycStatusSwitch(
                switchKey: state,
                duration: AppMotion.micro,
                child: SizedBox(
                  width: AppMotion.iconInline,
                  height: AppMotion.iconInline,
                  child: Icon(
                    trailing,
                    color: trailingColor,
                    size: AppMotion.iconInline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthOutlinedButton extends StatelessWidget {
  const AuthOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AuthLayout.buttonHeight,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: busy || !enabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AuthLayout.buttonHeight),
        maximumSize: const Size.fromHeight(AuthLayout.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: AppColors.brandPrimary,
        side: const BorderSide(color: AppColors.brandPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: busy ? 0 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: AppMotion.iconField),
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
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    ),
  );
}

class KycStepIntro extends StatelessWidget {
  const KycStepIntro({
    super.key,
    required this.current,
    required this.total,
    required this.title,
    required this.subtitle,
  });

  final int current;
  final int total;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        'Step $current of $total',
        style: const TextStyle(
          fontSize: AuthLayout.helperSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.brandPrimary,
        ),
      ),
      const SizedBox(height: AuthLayout.titleGap),
      Text(title, style: AuthLayout.title.copyWith(fontSize: 24)),
      const SizedBox(height: AuthLayout.titleGap),
      AppText(subtitle, style: AuthLayout.subtitle),
    ],
  );
}

class KycLocalFileCard extends StatelessWidget {
  const KycLocalFileCard({
    super.key,
    required this.title,
    required this.hint,
    required this.captureLabel,
    required this.emptyLabel,
    this.file,
    this.onCapture,
    this.onChoose,
    this.onReplace,
    this.onRemove,
    this.busy = false,
  });

  final String title;
  final String hint;
  final String captureLabel;
  final String emptyLabel;
  final PickedBytesFile? file;
  final VoidCallback? onCapture;
  final VoidCallback? onChoose;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;
  final bool busy;

  static const _previewable = {'jpg', 'jpeg', 'png', 'webp'};

  bool get _canPreview {
    final extension = file?.extension?.toLowerCase();
    return file != null && _previewable.contains(extension);
  }

  String get _sizeLabel {
    final bytes = file?.size ?? 0;
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final selected = file != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AuthLayout.bodySize,
            letterSpacing: 0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        AppText(
          hint,
          style: const TextStyle(
            fontSize: AuthLayout.helperSize,
            height: 1.4,
            letterSpacing: 0,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: AppRadius.borderSm,
          onTap: busy ? null : onChoose,
          child: Container(
            constraints: const BoxConstraints(minHeight: 170),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFE),
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: selected ? AppColors.brandPrimary : AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: KycStatusSwitch(
              switchKey: file?.name ?? 'empty',
              child: selected
                  ? Column(
                      children: [
                        SizedBox(
                          height: 148,
                          width: double.infinity,
                          child: _canPreview
                              ? Image.memory(
                                  file!.bytes,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: AppText('Preview unavailable'),
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.description_outlined,
                                      size: AppMotion.iconEmpty,
                                      color: AppColors.brandPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    AppText(
                                      file!.name,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            'Selected',
                            style: TextStyle(
                              fontSize: AuthLayout.helperSize,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                              color: AppColors.brandPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AppText(
                            '${file!.name} · $_sizeLabel',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.35,
                              letterSpacing: 0,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.upload_file,
                          size: AppMotion.iconEmpty,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(height: 10),
                        AppText(emptyLabel, textAlign: TextAlign.center),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AuthSubmitButton(
          label: captureLabel,
          onPressed: busy ? null : onCapture,
        ),
        const SizedBox(height: 8),
        AuthOutlinedButton(
          label: selected ? 'Replace File' : 'Choose File',
          icon: selected ? Icons.swap_horiz : Icons.upload_file,
          onPressed: busy ? null : (selected ? onReplace : onChoose),
        ),
        KycStatusSwitch(
          switchKey: selected ? 'remove' : 'idle',
          duration: AppMotion.micro,
          child: selected
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AuthOutlinedButton(
                    label: 'Remove File',
                    icon: Icons.delete_outline,
                    onPressed: busy ? null : onRemove,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class KycSelfieFrame extends StatelessWidget {
  const KycSelfieFrame({super.key, required this.bytes});

  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = (constraints.maxWidth - 8).clamp(160.0, 210.0);
      return Center(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.brandPrimary, width: 2),
          ),
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: KycStatusSwitch(
              switchKey: bytes == null ? 'empty' : identityHashCode(bytes),
              child: bytes == null
                  ? const ColoredBox(
                      color: Color(0xFFF5F8FF),
                      child: Icon(
                        Icons.face_outlined,
                        size: AppMotion.iconEmpty,
                        color: AppColors.brandPrimary,
                      ),
                    )
                  : Image.memory(
                      bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class KycFlowFooter extends StatelessWidget {
  const KycFlowFooter({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.errorText,
    this.helper = 'Used for identity verification',
    this.footerKey = const ValueKey('kyc-footer'),
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? errorText;
  final String helper;
  final Key footerKey;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = AuthLayout.formMaxWidth(media.size.width);
    final horizontal = AuthLayout.horizontalPadding(media.size.width);

    return DecoratedBox(
      key: footerKey,
      decoration: BoxDecoration(
        color: AuthLayout.pageBackground,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KycStatusSwitch(
                    switchKey: errorText ?? 'none',
                    child: errorText == null
                        ? const SizedBox.shrink()
                        : AuthFormError(message: errorText!),
                  ),
                  AuthSubmitButton(
                    label: label,
                    busy: busy,
                    onPressed: onPressed,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: AppText(
                          helper,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: AuthLayout.helperSize,
                            color: AppColors.textTertiary,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
