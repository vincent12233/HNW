import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// A centered, width-constrained empty state that remains balanced on phones,
/// tablets and large accessibility text sizes.
class ResponsiveEmptyState extends StatelessWidget {
  const ResponsiveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 380
            ? AppSpacing.xxl
            : AppSpacing.xxxl;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: AppSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(180.0, 420.0),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 38, color: color),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppText(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 2),
                    AppText(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      action!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
