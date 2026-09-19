import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';

class SectorPerformance extends StatelessWidget {
  const SectorPerformance({super.key, required this.stocks});

  final List<StockQuote> stocks;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StockQuote>>{};
    for (final stock in stocks) {
      final category = stock.category?.trim();
      if (category == null || category.isEmpty) continue;
      grouped.putIfAbsent(category, () => <StockQuote>[]).add(stock);
    }
    final sectors = grouped.entries.map((entry) {
      final change =
          entry.value.fold<double>(0, (total, stock) => total + stock.change) /
          entry.value.length;
      return (name: entry.key, change: change, count: entry.value.length);
    }).toList()..sort((left, right) => right.count.compareTo(left.count));

    if (sectors.isEmpty) {
      return AppCard(
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                'Sector classifications are currently unavailable.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Sector Performance',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: sectors.map((sector) {
            final change = sector.change;
            final color = change > 0
                ? AppColors.gain
                : change < 0
                ? AppColors.loss
                : AppColors.neutral;

            return SizedBox(
              width: 210,
              child: AppCard(
                radius: AppRadius.sm,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: Icon(Icons.category_outlined, color: color),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            sector.name,
                            style: AppTypography.labelLarge.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppText(
                            '${change > 0 ? '+' : ''}'
                            '${change.toStringAsFixed(2)}%',
                            style: AppTypography.labelMedium.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontFeatures: AppTypography.tabularFeatures,
                            ),
                          ),
                          AppText(
                            '${sector.count} stocks',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
