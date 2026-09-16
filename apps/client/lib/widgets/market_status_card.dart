import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Compact NSE session strip — mirrors Groww / Kite market-hours chrome.
class MarketStatusCard extends StatelessWidget {
  const MarketStatusCard({super.key, this.compact = true});

  final bool compact;

  bool _isMarketOpen() {
    final nowUtc = DateTime.now().toUtc();
    final indiaTime = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final weekday = indiaTime.weekday;
    final isWeekday = weekday >= DateTime.monday && weekday <= DateTime.friday;
    if (!isWeekday) return false;

    final minutes = indiaTime.hour * 60 + indiaTime.minute;
    const marketOpenMinutes = 9 * 60 + 15;
    const marketCloseMinutes = 15 * 60 + 30;
    return minutes >= marketOpenMinutes && minutes <= marketCloseMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _isMarketOpen();
    final statusColor = isOpen ? AppConfig.gainColor : AppConfig.lossColor;
    final statusText = isOpen ? 'NSE Open' : 'NSE Closed';
    final tint = isOpen
        ? AppConfig.gainColor.withValues(alpha: 0.08)
        : AppConfig.lossColor.withValues(alpha: 0.08);

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
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                statusText,
                style: AppTypography.labelMedium.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            AppText(
              '09:15 – 15:30 IST',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
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
              isOpen ? 'Market Open' : 'Market Closed',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const AppText(
            '09:15 - 15:30 IST',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
