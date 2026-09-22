import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Primary filled action — brand blue, 44dp min height.
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final labelWidget = AppText(
      label,
      textAlign: TextAlign.center,
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textInverse.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(child: labelWidget),
      ],
    );

    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      child: child,
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Outlined secondary action.
class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = icon == null
        ? OutlinedButton(
            onPressed: onPressed,
            child: AppText(label, textAlign: TextAlign.center),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 18),
            label: AppText(label, textAlign: TextAlign.center),
          );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Text-only tertiary action.
class AppTertiaryButton extends StatelessWidget {
  const AppTertiaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: destructive ? AppColors.loss : AppColors.brandPrimary,
      ),
      child: AppText(label, textAlign: TextAlign.center),
    );
  }
}

/// Trade semantic buttons — visual only, no logic change.
class AppBuyButton extends StatelessWidget {
  const AppBuyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : AppText(label, textAlign: TextAlign.center);

    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.buy,
        foregroundColor: AppColors.textInverse,
        disabledBackgroundColor: AppColors.disabled,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textInverse,
        ),
      ),
      child: child,
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class AppSellButton extends StatelessWidget {
  const AppSellButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : AppText(label, textAlign: TextAlign.center);

    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.sell,
        foregroundColor: AppColors.textInverse,
        disabledBackgroundColor: AppColors.disabled,
        minimumSize: Size(0, AppSpacing.buttonHeight),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        textStyle: AppTypography.labelLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textInverse,
        ),
      ),
      child: child,
    );

    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
