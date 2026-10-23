import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppText(
            title,
            style: AppTypography.sectionTitle.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),
        if (onViewAll != null)
          Semantics(
            button: true,
            label: tr('View all $title'),
            child: ExcludeSemantics(
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    AppMotion.tapTarget,
                    AppMotion.tapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                ),
                onPressed: onViewAll,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      'View All',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.brandPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
