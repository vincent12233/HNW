import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/trading_order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../../utils/order_status_presentation.dart';
import '../app_chip.dart';
import 'standard_order_details_sheet.dart';

class OrderCard extends StatefulWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.onCancel,
    this.compact = false,
  });

  final TradingOrder order;
  final Future<String?> Function(TradingOrder order)? onCancel;
  final bool compact;

  @override
  State<OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<OrderCard> {
  var _cancelling = false;

  TradingOrder get order => widget.order;
  Future<String?> Function(TradingOrder order)? get onCancel => widget.onCancel;
  bool get compact => widget.compact;

  @override
  Widget build(BuildContext context) {
    final side = order.isBuy ? 'BUY' : 'SELL';
    final sideColor = OrderStatusPresentation.sideColor(side);
    final displayPrice = order.limitPrice ?? order.price;
    final canCancel = OrderStatusPresentation.canCancel(order) && onCancel != null;
    final symbol = OrderStatusPresentation.missing(order.symbol);
    final exchange = OrderStatusPresentation.missing(order.exchange);
    final typeLine =
        '${OrderStatusPresentation.typeLabel(order.type)} · ${OrderStatusPresentation.tifLabel(order.timeInForce)}';
    final priceLabel = order.isLimit ? 'Limit' : 'Price';
    final priceText = displayPrice > 0 ? formatPrice(displayPrice) : '--';
    final filledLine = order.status == 'PARTIALLY_FILLED'
        ? '${order.filledQuantity} / ${order.quantity} filled'
        : 'Qty ${order.quantity} · Filled ${order.filledQuantity}';

    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.borderLg,
      child: InkWell(
        borderRadius: AppRadius.borderLg,
        onTap: () => showStandardOrderDetails(
          context,
          order: order,
          onCancel: canCancel ? onCancel : null,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: AppColors.border),
          ),
          padding: compact ? const EdgeInsets.all(AppSpacing.md) : AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.10),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: AppText(
                      OrderStatusPresentation.sideLabel(side),
                      style: AppTypography.labelSmall.copyWith(
                        color: sideColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          symbol,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        AppText(
                          '$exchange · $typeLine',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: AppStatusChip(
                        label: OrderStatusPresentation.label(order.status),
                        variant: OrderStatusPresentation.chipVariant(
                          order.status,
                        ),
                        compact: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppText(
                '$filledLine · $priceLabel $priceText',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.status == 'PARTIALLY_FILLED') ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: AppRadius.borderPill,
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: order.quantity <= 0
                        ? 0
                        : (order.filledQuantity / order.quantity).clamp(0, 1),
                    backgroundColor: AppColors.border,
                    color: AppColors.info,
                  ),
                ),
              ],
              if (order.status == 'REJECTED' &&
                  (order.rejectionReason?.trim().isNotEmpty ?? false)) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: AppMotion.iconInline,
                      color: AppColors.failed,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppText(
                        order.rejectionReason!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.failed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    OrderStatusPresentation.statusIcon(order.status),
                    size: AppMotion.iconInline,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppText(
                      OrderStatusPresentation.formatIst(order.placedAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: tr('View order details'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showStandardOrderDetails(
                        context,
                        order: order,
                        onCancel: canCancel ? onCancel : null,
                      ),
                      icon: Icon(
                        Icons.info_outline_rounded,
                        size: AppMotion.iconField,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (canCancel)
                      TextButton(
                        onPressed: _cancelling ? null : () => _cancel(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.loss,
                          minimumSize: const Size(
                            AppMotion.tapTarget,
                            AppMotion.tapTarget,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: AppText(_cancelling ? 'Cancelling...' : 'Cancel'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final cancel = onCancel;
    if (_cancelling ||
        cancel == null ||
        !OrderStatusPresentation.canCancel(order)) {
      return;
    }
    final confirmed = await confirmCancelTradingOrder(context, order: order);
    if (!confirmed || !context.mounted) return;
    setState(() => _cancelling = true);
    String? error;
    try {
      error = await cancel(order);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: AppText(error)));
    }
  }
}
