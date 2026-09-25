import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_card.dart';

class HomeActionButton extends StatelessWidget {
  const HomeActionButton({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.showChevron = true,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: AppCard(
        radius: AppRadius.md,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        onTap: onTap,
        borderColor: color.withValues(alpha: 0.16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < 150 ||
                  MediaQuery.textScalerOf(context).scale(13) > 18;
              final iconView = Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.borderSm,
                ),
                child: Icon(icon, color: color, size: 19),
              );
              final labels = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AppText(
                    subtitle,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelSmall,
                  ),
                ],
              );
              const arrow = Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        iconView,
                        if (showChevron) ...[const Spacer(), arrow],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    labels,
                  ],
                );
              }
              return Row(
                children: [
                  iconView,
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(child: labels),
                  if (showChevron && constraints.maxWidth >= 190) arrow,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
