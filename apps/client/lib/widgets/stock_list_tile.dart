import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';
import 'stock_logo.dart';

/// Standard equity row used across Markets, Search, and Watchlist.
class StockListTile extends StatelessWidget {
  const StockListTile({
    super.key,
    required this.stock,
    required this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.onLogoLoadFailed,
  });

  final StockQuote stock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLogoLoadFailed;

  double? get _absoluteChange {
    if (stock.previousClose != null && stock.previousClose! > 0) {
      return stock.price - stock.previousClose!;
    }
    if (stock.change == 0 || stock.price <= 0) return null;
    final previous = stock.price / (1 + stock.change / 100);
    if (previous <= 0) return null;
    return stock.price - previous;
  }

  Color get _changeColor {
    if (stock.change == 0) return AppColors.textSecondary;
    return stock.change > 0 ? AppColors.gain : AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    final absolute = _absoluteChange;
    final positive = stock.change > 0;
    final changeColor = _changeColor;
    final changeText = absolute == null
        ? '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%'
        : '${formatSignedPrice(absolute)}  (${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%)';

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md + 2,
          horizontal: AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Keep full financial values readable instead of squeezing them
            // beside the instrument name on small phones or at large text sizes.
            final stacked =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final quote = Column(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                AppText(
                  formatPrice(stock.price),
                  style: AppTypography.numericSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs + 1),
                AppText(
                  changeText,
                  style: AppTypography.labelSmall.copyWith(
                    color: changeColor,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFeatures,
                  ),
                ),
              ],
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StockLogo(
                  symbol: stock.symbol,
                  size: 36,
                  logoUrl: stock.logoUrl,
                  onLoadFailed: onLogoLoadFailed,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: AppText(
                              stock.symbol,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm - 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs + 1,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neutralSoft,
                              borderRadius: AppRadius.borderSm,
                            ),
                            child: AppText(
                              stock.exchange,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (!stock.quoteFresh) ...[
                            const SizedBox(width: AppSpacing.sm - 2),
                            Tooltip(
                              message: tr('Delayed quote'),
                              child: Icon(
                                Icons.schedule,
                                size: 14,
                                color: AppColors.warning,
                                semanticLabel: tr('Delayed quote'),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      AppText(
                        stock.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (stacked) ...[
                        const SizedBox(height: AppSpacing.sm),
                        quote,
                      ],
                    ],
                  ),
                ),
                if (!stacked) ...[
                  const SizedBox(width: AppSpacing.sm + 2),
                  Flexible(child: quote),
                ],
                if (onFavorite != null)
                  IconButton(
                    onPressed: onFavorite,
                    tooltip: isFavorite
                        ? tr('Remove from watchlist')
                        : tr('Add to watchlist'),
                    visualDensity: VisualDensity.standard,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    icon: Icon(
                      isFavorite ? Icons.star : Icons.star_border,
                      size: 20,
                      color: isFavorite
                          ? AppColors.warning
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
