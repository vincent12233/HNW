import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../models/picked_bytes_file.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import 'onboarding_auth_widgets.dart';

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
