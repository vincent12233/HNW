import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/trading_order.dart';
import '../../utils/number_formatters.dart';

Future<void> showStandardOrderDetails(
  BuildContext context, {
  required TradingOrder order,
  Future<String?> Function(TradingOrder order)? onCancel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _StandardOrderDetailsSheet(order: order, onCancel: onCancel),
  );
}

class _StandardOrderDetailsSheet extends StatefulWidget {
  const _StandardOrderDetailsSheet({required this.order, this.onCancel});

  final TradingOrder order;
  final Future<String?> Function(TradingOrder order)? onCancel;

  @override
  State<_StandardOrderDetailsSheet> createState() =>
      _StandardOrderDetailsSheetState();
}

class _StandardOrderDetailsSheetState
    extends State<_StandardOrderDetailsSheet> {
  bool cancelling = false;
  bool confirmingCancellation = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final sideColor = order.isBuy ? AppConfig.gainColor : AppConfig.lossColor;
    final statusColor = _statusColor(order.status);
    final displayPrice = order.limitPrice ?? order.price;
    final averageFillPrice = order.filledQuantity > 0
        ? order.averageFillPrice
        : null;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AppText(
                order.symbol,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                '${tr(order.type == 'LIMIT' ? 'Limit Order' : 'Market Order')} · ${order.timeInForce}',
                style: const TextStyle(color: AppConfig.textSecondaryColor),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _pill(order.isBuy ? 'BUY' : 'SELL', sideColor),
                  _pill(_statusLabel(order.status), statusColor),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConfig.surfaceMutedColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppConfig.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _value('Order Quantity', '${order.quantity}'),
                        ),
                        Expanded(
                          child: _value(
                            'Filled Quantity',
                            '${order.filledQuantity}',
                          ),
                        ),
                        Expanded(
                          child: _value(
                            'Remaining Quantity',
                            '${order.remainingQuantity}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _value(
                            order.isLimit ? 'Limit Price' : 'Order Price',
                            displayPrice > 0 ? formatPrice(displayPrice) : '--',
                          ),
                        ),
                        Expanded(
                          child: _value(
                            'Avg. Fill Price',
                            averageFillPrice != null && averageFillPrice > 0
                                ? formatPrice(averageFillPrice)
                                : '--',
                          ),
                        ),
                        Expanded(
                          child: _value(
                            'Order Value',
                            displayPrice > 0
                                ? formatPrice(order.quantity * displayPrice)
                                : '--',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _detailRow(
                'Order Type',
                order.type == 'LIMIT' ? 'Limit Order' : 'Market Order',
              ),
              _detailRow('Exchange', order.exchange),
              _detailRow('Validity', order.timeInForce),
              _detailRow('Placed', order.formattedTime),
              if (order.clientOrderId?.isNotEmpty == true)
                _detailRow('Reference', order.clientOrderId!),
              if (order.orderId?.isNotEmpty == true)
                _detailRow('Order ID', order.orderId!),
              const SizedBox(height: 18),
              const AppText(
                'Order timeline',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _timelineItem(
                label: 'Submitted',
                time: order.placedAt,
                color: AppConfig.primaryColor,
                last:
                    order.updatedAt == null &&
                    order.completedAt == null &&
                    order.cancelledAt == null,
              ),
              if (order.updatedAt != null &&
                  order.updatedAt != order.completedAt &&
                  order.updatedAt != order.cancelledAt)
                _timelineItem(
                  label: _statusLabel(order.status),
                  time: order.updatedAt!,
                  color: statusColor,
                  last: order.completedAt == null && order.cancelledAt == null,
                ),
              if (order.completedAt != null && order.cancelledAt == null)
                _timelineItem(
                  label: 'Filled',
                  time: order.completedAt!,
                  color: AppConfig.gainColor,
                  last: true,
                ),
              if (order.cancelledAt != null)
                _timelineItem(
                  label: 'Cancelled',
                  time: order.cancelledAt!,
                  color: AppConfig.neutralColor,
                  last: true,
                ),
              if (order.fills.isNotEmpty) ...[
                const SizedBox(height: 8),
                const AppText(
                  'Executions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...order.fills.map(_executionCard),
                const SizedBox(height: 4),
                _detailRow(
                  'Total fees',
                  formatPrice(
                    order.fills.fold<double>(
                      0,
                      (total, fill) => total + fill.fees,
                    ),
                  ),
                ),
                _detailRow(
                  'Net amount',
                  formatPrice(
                    order.fills.fold<double>(
                      0,
                      (total, fill) => total + fill.netAmount,
                    ),
                  ),
                ),
              ],
              if (order.isActive && widget.onCancel != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: cancelling ? null : _cancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConfig.lossColor,
                      side: BorderSide(color: AppConfig.lossColor),
                    ),
                    child: AppText(
                      cancelling ? 'Cancelling...' : 'Cancel Order',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel() async {
    if (cancelling || confirmingCancellation || widget.onCancel == null) return;
    confirmingCancellation = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Cancel Order?'),
        content: AppText(
          'Cancel the remaining ${widget.order.remainingQuantity} shares of '
          '${widget.order.symbol} ${widget.order.isBuy ? 'BUY' : 'SELL'} order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppConfig.lossColor),
            child: const AppText('Cancel Order'),
          ),
        ],
      ),
    );
    confirmingCancellation = false;
    if (confirmed != true || !mounted) return;

    setState(() => cancelling = true);
    String? error;
    try {
      error = await widget.onCancel!(widget.order);
    } catch (_) {
      error =
          'Unable to confirm cancellation. Refresh your orders to check the latest status.';
    } finally {
      if (mounted) setState(() => cancelling = false);
    }
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error)));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: AppText('${widget.order.symbol} order cancelled')),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppText(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _value(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: AppConfig.textSecondaryColor, fontSize: 11),
        ),
        const SizedBox(height: 5),
        AppText(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: AppText(
              label,
              style: const TextStyle(color: AppConfig.textSecondaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timelineItem({
    required String label,
    required DateTime time,
    required Color color,
    required bool last,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppConfig.borderColor),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    _formatTimelineTime(time),
                    style: const TextStyle(
                      color: AppConfig.textSecondaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _executionCard(TradingFill fill) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConfig.surfaceMutedColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${fill.quantity} @ ${formatPrice(fill.price)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              AppText(
                _formatTimelineTime(fill.executedAt),
                style: const TextStyle(color: AppConfig.textSecondaryColor, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppText(
            'Gross ${formatPrice(fill.grossAmount)}  |  '
            'Fees ${formatPrice(fill.fees)}',
            style: const TextStyle(color: AppConfig.textSecondaryColor, fontSize: 11),
          ),
          if (fill.executionId.isNotEmpty) ...[
            const SizedBox(height: 4),
            SelectableText(
              fill.executionId,
              style: const TextStyle(color: AppConfig.textSecondaryColor, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTimelineTime(DateTime value) {
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(ist.day)}/${two(ist.month)} '
        '${two(ist.hour)}:${two(ist.minute)}:${two(ist.second)} IST';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'PARTIALLY_FILLED':
        return 'Partial';
      case 'FILLED':
        return 'Completed';
      case 'CANCELLED':
        return 'Cancelled';
      case 'REJECTED':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'FILLED':
        return AppConfig.gainColor;
      case 'CANCELLED':
        return AppConfig.neutralColor;
      case 'REJECTED':
        return AppConfig.lossColor;
      default:
        return AppConfig.primaryColor;
    }
  }
}
