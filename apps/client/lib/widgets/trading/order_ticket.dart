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
import '../../utils/number_formatters.dart';
import '../app_card.dart';
import '../market_status_card.dart';

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
            labelText: 'Quantity',
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
                      labelText: 'Limit Price',
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
      return _OrderConfirmDialog(
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

class _OrderConfirmDialog extends StatefulWidget {
  const _OrderConfirmDialog({
    required this.stock,
    required this.isBuy,
    required this.orderType,
    required this.timeInForce,
    required this.quantity,
    required this.estimatedAmount,
    required this.onConfirm,
    this.limitPrice,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.riskNotice,
  });

  final StockQuote stock;
  final bool isBuy;
  final String orderType;
  final String timeInForce;
  final int quantity;
  final double estimatedAmount;
  final double? limitPrice;
  final bool? marketOpen;
  final String marketHours;
  final String? riskNotice;
  final Future<String?> Function() onConfirm;

  @override
  State<_OrderConfirmDialog> createState() => _OrderConfirmDialogState();
}

class _OrderConfirmDialogState extends State<_OrderConfirmDialog> {
  bool _submitting = false;
  String? _error;

  bool get _canSubmit =>
      !_submitting && widget.marketOpen != false && widget.quantity > 0;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await widget.onConfirm();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final side = widget.isBuy ? 'BUY' : 'SELL';
    return RepaintBoundary(
      key: const Key('order-preview-surface'),
      child: AlertDialog(
        title: AppText(widget.isBuy ? 'Confirm Buy' : 'Confirm Sell'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line('Instrument', widget.stock.symbol),
                _line('Exchange', widget.stock.exchange),
                _line('Side', side),
                _line(
                  'Order type',
                  widget.orderType == 'LIMIT' ? 'LIMIT' : 'MARKET',
                ),
                _line('Time in force', widget.timeInForce),
                _line('Quantity', '${widget.quantity}'),
                if (widget.orderType == 'LIMIT')
                  _line(
                    'Limit price',
                    widget.limitPrice == null
                        ? '--'
                        : formatPrice(widget.limitPrice!),
                  ),
                _line('Estimated amount', formatPrice(widget.estimatedAmount)),
                _line('Fees', formatPrice(0)),
                _line('Market', switch (widget.marketOpen) {
                  true => 'Open · ${widget.marketHours}',
                  false => 'Closed · ${widget.marketHours}',
                  null => 'Status unavailable · ${widget.marketHours}',
                }),
                if (widget.riskNotice != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppText(
                    widget.riskNotice!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                AppText(
                  'Review only. Confirm sends one order using the current request id.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppFadeIn(
                    switchKey: _error!,
                    child: AppText(
                      _error!,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.loss,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            key: const Key('order-confirm'),
            onPressed: _canSubmit ? _submit : null,
            child: AppText(_submitting ? 'Submitting...' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
