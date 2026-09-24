import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/stock_quote.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../home/home_dashboard_data.dart';
import '../stock_logo.dart';

class StockQuoteHero extends StatelessWidget {
  const StockQuoteHero({
    super.key,
    required this.stock,
    required this.quotesConnected,
  });

  final StockQuote stock;
  final bool quotesConnected;

  @override
  Widget build(BuildContext context) {
    final available = stock.price > 0;
    final delayed =
        !stock.quoteFresh || quotesAreStale([stock]) || !quotesConnected;
    final changeColor = !available
        ? AppColors.textInverse.withValues(alpha: 0.72)
        : stock.change > 0
        ? AppColors.chartGain
        : stock.change < 0
        ? AppColors.lossSoft
        : AppColors.textInverse.withValues(alpha: 0.8);
    final absolute = stock.previousClose != null && stock.previousClose! > 0
        ? stock.price - stock.previousClose!
        : null;
    final muted = AppColors.textInverse.withValues(alpha: 0.72);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: AppRadius.borderSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StockLogo(symbol: stock.symbol, logoUrl: stock.logoUrl, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      stock.name.isEmpty ? stock.symbol : stock.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.textInverse,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    AppText(
                      '${stock.symbol} · ${stock.exchange}',
                      style: AppTypography.caption.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              _StatusChip(delayed: delayed, connected: quotesConnected),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppText(
            available ? formatPrice(stock.price) : '--',
            style: AppTypography.numericInverse.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                !available
                    ? Icons.remove
                    : stock.change > 0
                    ? Icons.arrow_drop_up_rounded
                    : stock.change < 0
                    ? Icons.arrow_drop_down_rounded
                    : Icons.remove,
                color: changeColor,
                size: AppMotion.iconToolbar,
              ),
              Flexible(
                child: AppText(
                  available
                      ? '${absolute == null ? '' : '${formatSignedPrice(absolute)}  '}'
                            '(${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%)'
                      : 'Quote unavailable',
                  style: AppTypography.labelLarge.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AppTypography.tabularFeatures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            delayed
                ? 'Delayed · updated ${homeRelativeTime(stock.updatedAt)}'
                : 'Updated ${homeRelativeTime(stock.updatedAt)}',
            style: AppTypography.caption.copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.delayed, required this.connected});

  final bool delayed;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final label = !connected
        ? 'OFFLINE'
        : delayed
        ? 'DELAYED'
        : 'LIVE';
    final color = !connected
        ? AppColors.textInverse.withValues(alpha: 0.7)
        : delayed
        ? AppColors.warning
        : AppColors.chartGain;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.textInverse.withValues(alpha: 0.12),
          borderRadius: AppRadius.borderSm,
        ),
        child: AppText(
          label,
          style: AppTypography.caption.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
