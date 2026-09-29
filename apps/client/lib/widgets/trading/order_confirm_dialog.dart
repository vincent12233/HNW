import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../models/stock_quote.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';

class OrderConfirmDialog extends StatefulWidget {
  const OrderConfirmDialog({
    required this.stock,
    super.key,
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
  State<OrderConfirmDialog> createState() => OrderConfirmDialogState();
}

class OrderConfirmDialogState extends State<OrderConfirmDialog> {
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

