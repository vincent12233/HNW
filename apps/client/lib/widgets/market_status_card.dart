import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Server-confirmed session state. Local clock time cannot identify holidays
/// or an unavailable market-data service.
class MarketStatusCard extends StatelessWidget {
  const MarketStatusCard({
    super.key,
    this.compact = true,
    this.isOpen,
    this.hours = '09:15 - 15:30 IST',
    this.quotesConnected,
  });

  final bool compact;
  final bool? isOpen;
  final String hours;
  final bool? quotesConnected;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (isOpen) {
      true => AppConfig.gainColor,
      false => AppColors.textSecondary,
      null => AppColors.warning,
    };
    final statusText = switch (isOpen) {
      true => 'NSE Open',
      false => 'NSE Closed',
      null => 'Market status unavailable',
    };
    final tint = statusColor.withValues(alpha: 0.08);

    if (compact) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: AppRadius.borderSm,
          border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: statusColor),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppText(
                        statusText,
                        style: AppTypography.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                AppText(
                  hours,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            if (quotesConnected == false) ...[
              const SizedBox(height: AppSpacing.xs),
              AppText(
                'Live quotes reconnecting. Prices may be delayed.',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        borderRadius: AppRadius.borderMd,
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brandPrimary],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Flexible(
            child: AppText(
              hours,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
