import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_language.dart';
import '../../models/stock_quote.dart';
import '../../services/trading_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../market_status_card.dart';
import 'order_confirm_dialog.dart';

class OrderTicketPanel extends StatelessWidget {
  const OrderTicketPanel({
    super.key,
    required this.stock,
    required this.isBuy,
    required this.orderType,
    required this.timeInForce,
    required this.quantityController,
    required this.limitPriceController,
    required this.onBuyChanged,
    required this.onOrderTypeChanged,
    required this.onTimeInForceChanged,
    required this.onChanged,
    this.account,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
    this.quantityError,
    this.priceError,
  });

  final StockQuote stock;
  final bool isBuy;
  final String orderType;
  final String timeInForce;
  final TextEditingController quantityController;
  final TextEditingController limitPriceController;
  final ValueChanged<bool> onBuyChanged;
  final ValueChanged<String> onOrderTypeChanged;
  final ValueChanged<String> onTimeInForceChanged;
  final VoidCallback onChanged;
  final TradingAccountSnapshot? account;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;
  final String? quantityError;
  final String? priceError;

  bool get isLimit => orderType == 'LIMIT';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MarketStatusCard(
          isOpen: marketOpen,
          hours: marketHours,
          quotesConnected: quotesConnected,
        ),
        if (marketOpen == false) ...[
          const SizedBox(height: AppSpacing.sm),
          AppText(
            'The exchange session is closed. New orders cannot be submitted until the market opens. The server still verifies session state.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppText(
          'Place Order',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        AppText(
          '${stock.symbol} · ${stock.exchange}',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment<bool>(
              value: true,
              label: AppText('Buy'),
              tooltip: tr('Buy'),
            ),
            ButtonSegment<bool>(
              value: false,
              label: AppText('Sell'),
              tooltip: tr('Sell'),
            ),
          ],
          selected: {isBuy},
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.textInverse;
              }
              return AppColors.textPrimary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (!states.contains(WidgetState.selected)) {
                return AppColors.surface;
              }
              return isBuy ? AppColors.buy : AppColors.sell;
            }),
          ),
          onSelectionChanged: (selection) => onBuyChanged(selection.first),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in const ['MARKET', 'LIMIT'])
              ChoiceChip(
                label: AppText(
                  value == 'MARKET' ? 'Market Order' : 'Limit Order',
                ),
                selected: orderType == value,
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: orderType == value
                      ? AppColors.textInverse
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: orderType == value
                      ? AppColors.brandPrimary
                      : AppColors.border,
                ),
                onSelected: (_) => onOrderTypeChanged(value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppText(
          isLimit
              ? 'A limit order waits at your price and is valid for the selected period.'
              : 'A market order uses the current bid or ask. The fill price can differ from this estimate.',
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: tr('Quantity'),
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.numbers),
            errorText: quantityError,
          ),
        ),
        AppFadeIn(
          switchKey: isLimit ? 'limit' : 'market',
          child: isLimit
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: TextField(
                    controller: limitPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => onChanged(),
                    decoration: InputDecoration(
                      labelText: tr('Limit Price'),
                      prefixText: '₹ ',
                      border: const OutlineInputBorder(),
                      errorText: priceError,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: AppSpacing.md),
        const AppText(
          'Validity',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in const ['DAY', 'IOC', 'FOK'])
              Semantics(
                button: true,
                selected: timeInForce == value,
                label: switch (value) {
                  'IOC' => 'Immediate or Cancel',
                  'FOK' => 'Fill or Kill',
                  _ => 'Valid for the trading day',
                },
                child: Tooltip(
                  message: switch (value) {
                    'IOC' => 'Immediate or Cancel',
                    'FOK' => 'Fill or Kill',
                    _ => 'Valid for the trading day',
                  },
                  child: ChoiceChip(
                    label: AppText(value),
                    selected: timeInForce == value,
                    selectedColor: AppColors.brandPrimary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: timeInForce == value
                          ? AppColors.textInverse
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: timeInForce == value
                          ? AppColors.brandPrimary
                          : AppColors.border,
                    ),
                    onSelected: (_) => onTimeInForceChanged(value),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class OrderTicketBar extends StatelessWidget {
  const OrderTicketBar({
    super.key,
    required this.onBuy,
    required this.onSell,
    this.submitting = false,
    this.enabled = true,
  });

  final VoidCallback onBuy;
  final VoidCallback onSell;
  final bool submitting;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.lg,
        AppSpacing.sm + 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSpacing.buttonHeight + 4,
              child: FilledButton(
                onPressed: !enabled || submitting ? null : onBuy,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.buy,
                  foregroundColor: AppColors.textInverse,
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: AppText(
                  'BUY',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: SizedBox(
              height: AppSpacing.buttonHeight + 4,
              child: FilledButton(
                onPressed: !enabled || submitting ? null : onSell,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sell,
                  foregroundColor: AppColors.textInverse,
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: AppText(
                  'SELL',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showOrderConfirmDialog({
  required BuildContext context,
  required StockQuote stock,
  required bool isBuy,
  required String orderType,
  required String timeInForce,
  required int quantity,
  required double estimatedAmount,
  required Future<String?> Function() onConfirm,
  double? limitPrice,
  bool? marketOpen,
  String marketHours = '09:15 - 15:30 IST',
  String? riskNotice,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return OrderConfirmDialog(
        stock: stock,
        isBuy: isBuy,
        orderType: orderType,
        timeInForce: timeInForce,
        quantity: quantity,
        estimatedAmount: estimatedAmount,
        limitPrice: limitPrice,
        marketOpen: marketOpen,
        marketHours: marketHours,
        riskNotice: riskNotice,
        onConfirm: onConfirm,
      );
    },
  );
}
