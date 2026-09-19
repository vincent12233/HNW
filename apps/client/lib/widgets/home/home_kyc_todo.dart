import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'home_dashboard_data.dart';

class HomeKycTodoCard extends StatelessWidget {
  const HomeKycTodoCard({super.key, required this.todo, required this.onOpen});

  final HomeKycTodo todo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (todo == HomeKycTodo.hidden) return const SizedBox.shrink();
    final pending = todo == HomeKycTodo.pending;
    final rejected = todo == HomeKycTodo.rejected;
    final title = pending
        ? 'KYC pending review'
        : rejected
        ? 'KYC action required'
        : 'Verification status unavailable';
    final subtitle = pending
        ? 'Documents are waiting for review.'
        : rejected
        ? 'Open verification to see the latest review note.'
        : 'Status could not be confirmed from the current session.';
    final color = rejected
        ? AppColors.loss
        : pending
        ? AppColors.pending
        : AppColors.textSecondary;
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.borderSm,
        child: InkWell(
          onTap: onOpen,
          borderRadius: AppRadius.borderSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  pending
                      ? Icons.hourglass_top_rounded
                      : rejected
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  color: color,
                  size: AppMotion.iconField,
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        title,
                        style: AppTypography.labelLarge.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      AppText(
                        subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                  size: AppMotion.iconToolbar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
