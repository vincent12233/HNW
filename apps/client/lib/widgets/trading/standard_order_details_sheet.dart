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
    builder: (_) => _StandardOrderDetailsSheet(order: order, onCancel: onCancel),
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final sideColor = order.isBuy ? AppConfig.gainColor : AppConfig.lossColor;
    final statusColor = _statusColor(order.status);
    final displayPrice = order.limitPrice ?? order.price;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.symbol,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.type == 'LIMIT' ? 'Limit' : 'Market'} Order • ${order.timeInForce}',
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  _pill(order.isBuy ? 'BUY' : 'SELL', sideColor),
                  const SizedBox(width: 8),
                  _pill(_statusLabel(order.status), statusColor),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _value('Order Qty', '${order.quantity}')),
                        Expanded(
                          child: _value('Filled', '${order.filledQuantity}'),
                        ),
                        Expanded(
                          child: _value('Remaining', '${order.remainingQuantity}'),
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
                            order.price > 0 ? formatPrice(order.price) : '--',
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
              _detailRow('Order Type', order.type == 'LIMIT' ? 'Limit' : 'Market'),
              _detailRow('Validity', order.timeInForce),
              _detailRow('Placed', order.formattedTime),
              if (order.clientOrderId?.isNotEmpty == true)
                _detailRow('Reference', order.clientOrderId!),
              if (order.orderId?.isNotEmpty == true)
                _detailRow('Order ID', order.orderId!),
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
                    child: Text(cancelling ? 'Cancelling...' : 'Cancel Order'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Text(
          'Cancel the remaining ${widget.order.remainingQuantity} shares of '
          '${widget.order.symbol} ${widget.order.isBuy ? 'BUY' : 'SELL'} order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppConfig.lossColor),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => cancelling = true);
    final error = await widget.onCancel!(widget.order);
    if (!mounted) return;
    setState(() => cancelling = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.order.symbol} order cancelled')),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _value(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
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
        return const Color(0xFF2563EB);
    }
  }
}
