import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../models/portfolio_position.dart';
import '../models/stock_quote.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';

int holdingFrozenQuantity(PortfolioPosition position) =>
    (position.quantity - position.availableQuantity).clamp(0, position.quantity);

bool holdingQuoteUsable(StockQuote? quote) =>
    quote != null && quote.price > 0;

String holdingIst(DateTime value) {
  final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(ist.day)}/${two(ist.month)}/${ist.year} '
      '${two(ist.hour)}:${two(ist.minute)} IST';
}

Future<void> showHoldingDetails(
  BuildContext context, {
  required PortfolioPosition position,
  StockQuote? quote,
  ValueChanged<StockQuote>? onSell,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final frozen = holdingFrozenQuantity(position);
      final usableQuote = holdingQuoteUsable(quote);
      final delayed = quote != null && !quote.quoteFresh;
      final currentPrice = usableQuote ? quote!.price : null;
      final invested = position.quantity * position.averageCost;
      final currentValue = currentPrice == null
          ? null
          : position.marketValue(currentPrice);
      final unrealized = currentPrice == null
          ? null
          : position.unrealizedProfitLoss(currentPrice);
      final dayPnl =
          currentPrice != null &&
              quote?.previousClose != null &&
              quote!.previousClose! > 0
          ? (currentPrice - quote.previousClose!) * position.quantity
          : null;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxl,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  position.symbol,
                  style: AppTypography.headline.copyWith(fontSize: 20),
                ),
                AppText(
                  position.name.isEmpty ? '--' : position.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _chip(position.exchange),
                    _chip(position.category.isEmpty ? 'Equity' : position.category),
                    _chip(frozen > 0 ? 'Open · Frozen' : 'Open holding'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _row('Quantity', '${position.quantity}'),
                _row('Available', '${position.availableQuantity}'),
                _row('Frozen', '$frozen'),
                _row('Average cost', formatPrice(position.averageCost)),
                _row(
                  'Current price',
                  currentPrice == null ? 'Unavailable' : formatPrice(currentPrice),
                ),
                if (delayed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppText(
                      'Market quote is delayed.',
                      style: AppTypography.caption.copyWith(color: AppColors.warning),
                    ),
                  ),
                _row(
                  'Current value',
                  currentValue == null ? 'Unavailable' : formatPrice(currentValue),
                ),
                _row('Invested', formatPrice(invested)),
                _row(
                  'Realized P&L',
                  '${formatSignedPrice(position.realizedProfitLoss)} · '
                  '${_word(position.realizedProfitLoss)}',
                ),
                _row(
                  'Unrealized P&L',
                  unrealized == null
                      ? 'Unavailable'
                      : '${formatSignedPrice(unrealized)} · ${_word(unrealized)}',
                ),
                _row(
                  'Day P&L',
                  dayPnl == null
                      ? 'Unavailable'
                      : '${formatSignedPrice(dayPnl)} · ${_word(dayPnl)}',
                ),
                _row(
                  'Updated',
                  quote == null ? 'Unavailable' : holdingIst(quote.updatedAt),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppText(
                  'Fill history is not included in this holding record.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
                if (onSell != null && quote != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    height: AppMotion.tapTarget,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        onSell(quote);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.loss,
                        foregroundColor: AppColors.textInverse,
                      ),
                      child: const AppText('Sell'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

String _word(num value) {
  if (value > 0) return 'Gain';
  if (value < 0) return 'Loss';
  return 'Unchanged';
}

Widget _chip(String label) {
  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(6),
    ),
    child: AppText(label, style: AppTypography.labelSmall),
  );
}

Widget _row(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: AppText(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: AppText(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
