import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/stock_quote.dart';
import '../../services/trading_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../app_card.dart';

class OrderEstimateCard extends StatelessWidget {
  const OrderEstimateCard({
    super.key,
    required this.stock,
    required this.isBuy,
    required this.isLimit,
    required this.quantity,
    required this.selectedPrice,
    required this.estimatedAmount,
    this.account,
    this.maxQuantity,
    this.deviationPercent,
    this.quoteReady = true,
    this.onUseMax,
  });

  final StockQuote stock;
  final bool isBuy;
  final bool isLimit;
  final int quantity;
  final double selectedPrice;
  final double estimatedAmount;
  final TradingAccountSnapshot? account;
  final int? maxQuantity;
  final double? deviationPercent;
  final bool quoteReady;
  final VoidCallback? onUseMax;

  @override
  Widget build(BuildContext context) {
    final largeDeviation =
        deviationPercent != null && deviationPercent!.abs() >= 5;
    final exceeds =
        maxQuantity != null && quantity > maxQuantity! && quantity > 0;
    return AppCard(
      radius: AppRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Order details',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppText(
                selectedPrice > 0 ? formatPrice(estimatedAmount) : '--',
                style: AppTypography.numericSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _row(
            'Indicative price',
            selectedPrice > 0 ? formatPrice(selectedPrice) : '--',
          ),
          _row(
            'Price basis',
            isLimit
                ? 'Limit price'
                : isBuy
                ? 'Current best ask'
                : 'Current best bid',
          ),
          if (account != null) ...[
            _row('Available funds', formatPrice(account!.availableBalance)),
            _row('Frozen funds', formatPrice(account!.frozenBalance)),
            if (isBuy) _row('Buying power', formatPrice(account!.buyingPower)),
          ],
          if (!isBuy && maxQuantity != null)
            _row('Available to sell', '$maxQuantity shares'),
          _row('Fees', formatPrice(0)),
          AppText(
            'Fees are currently 0. Brokerage or tax is not estimated in this app.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (maxQuantity != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: maxQuantity! <= 0 ? null : onUseMax,
                child: const AppText('Use max'),
              ),
            ),
          const Divider(height: 20),
          AppText(
            'This is an estimate. Final execution price and charges come from the order result.',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (largeDeviation || exceeds) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              exceeds
                  ? isBuy
                        ? 'Estimated amount exceeds available buying power.'
                        : 'Sell quantity exceeds the available holding.'
                  : 'Limit price is ${deviationPercent!.abs().toStringAsFixed(2)}% '
                        '${deviationPercent! >= 0 ? 'above' : 'below'} the current price.',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (!quoteReady) ...[
            const SizedBox(height: AppSpacing.sm),
            AppText(
              'A current market quote is required before submission.',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.loss,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AppText(
            value,
            style: AppTypography.labelMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
