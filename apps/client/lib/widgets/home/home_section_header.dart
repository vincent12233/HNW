import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.onViewAll,
    this.compact = false,
  });

  final String title;
  final VoidCallback? onViewAll;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleWidget = AppText(
      title,
      style: (compact ? AppTypography.labelMedium : AppTypography.sectionTitle)
          .copyWith(fontWeight: FontWeight.w800, letterSpacing: 0),
    );
    final action = onViewAll == null
        ? null
        : Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: '${tr('View All')} ${tr(title)}',
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
                  child: compact
                      ? AppText(
                          'View All',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.brandPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Row(
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
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final stacked = constraints.maxWidth < 240 || scale > 1.4;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, ?action],
          );
        }
        return Row(
          children: [
            Expanded(child: titleWidget),
            ?action,
          ],
        );
      },
    );
  }
}
