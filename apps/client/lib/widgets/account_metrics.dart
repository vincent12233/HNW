import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class AccountMetric {
  const AccountMetric(
    this.label,
    this.value, {
    this.color = AppColors.textPrimary,
  });

  final String label;
  final String value;
  final Color color;
}

/// Reflow account figures instead of shrinking financial values to fit a row.
class AccountMetrics extends StatelessWidget {
  const AccountMetrics({super.key, required this.items});

  final List<AccountMetric> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = (constraints.maxWidth / (150 * scale)).floor().clamp(
          1,
          items.length,
        );
        final width =
            (constraints.maxWidth - AppSpacing.lg * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(item.label, style: AppTypography.caption),
                      const SizedBox(height: AppSpacing.xs),
                      AppText(
                        item.value,
                        style: AppTypography.numericSmall.copyWith(
                          color: item.color,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class AccountDataStatus extends StatelessWidget {
  const AccountDataStatus({
    super.key,
    required this.hasData,
    required this.refreshing,
    required this.failed,
    required this.onRetry,
  });

  final bool hasData;
  final bool refreshing;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hasData && !refreshing && !failed) return const SizedBox.shrink();
    final message = refreshing
        ? 'Updating balances…'
        : hasData
        ? 'Balances could not be refreshed. Showing previously loaded values.'
        : 'Balances are unavailable. Please retry.';
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (refreshing) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppText(
              message,
              style: AppTypography.bodySmall.copyWith(
                color: failed ? AppColors.loss : AppColors.textSecondary,
              ),
            ),
            if (!refreshing)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const AppText('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}
