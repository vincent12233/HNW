import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppChipVariant { neutral, info, success, pending, failed, gain, loss }

/// Semantic status / category chip using design tokens.
class AppStatusChip extends StatelessWidget {
  const AppStatusChip({
    super.key,
    required this.label,
    this.variant = AppChipVariant.neutral,
    this.compact = false,
  });

  final String label;
  final AppChipVariant variant;
  final bool compact;

  (Color fg, Color bg) get _colors => switch (variant) {
    AppChipVariant.neutral => (AppColors.neutral, AppColors.neutralSoft),
    AppChipVariant.info => (AppColors.info, AppColors.infoSoft),
    AppChipVariant.success => (AppColors.success, AppColors.successSoft),
    AppChipVariant.pending => (AppColors.pending, AppColors.pendingSoft),
    AppChipVariant.failed => (AppColors.failed, AppColors.failedSoft),
    AppChipVariant.gain => (AppColors.gain, AppColors.gainSoft),
    AppChipVariant.loss => (AppColors.loss, AppColors.lossSoft),
  };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? AppSpacing.xxs + 1 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: fg.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.labelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10 : 11,
        ),
      ),
    );
  }
}
