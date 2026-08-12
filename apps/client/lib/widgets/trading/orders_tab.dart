import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/trading_order.dart';
import '../../utils/number_formatters.dart';
import 'standard_order_details_sheet.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({
    super.key,
    required this.orders,
    this.onCancel,
  });

  final List<TradingOrder> orders;
  final Future<String?> Function(TradingOrder order)? onCancel;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 64, color: Colors.black38),
              SizedBox(height: 16),
              Text('No orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                'Your order activity will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        final sideColor = order.isBuy ? AppConfig.gainColor : AppConfig.lossColor;
        final displayPrice = order.limitPrice ?? order.price;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showStandardOrderDetails(
            context,
            order: order,
            onCancel: order.isActive ? onCancel : null,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sideColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.isBuy ? 'BUY' : 'SELL',
                        style: TextStyle(color: sideColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order.symbol, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(
                            '${order.type == 'LIMIT' ? 'Limit' : 'Market'} • ${order.timeInForce}',
                            style: const TextStyle(color: Colors.black45, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _statusLabel(order.status),
                      style: TextStyle(color: _statusColor(order.status), fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.black38),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: _value('Qty', '${order.quantity}')),
                    Expanded(
                      child: _value(
                        order.isLimit ? 'Limit' : 'Price',
                        displayPrice > 0 ? formatPrice(displayPrice) : '--',
                      ),
                    ),
                    Expanded(child: _value('Filled', '${order.filledQuantity}')),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(order.formattedTime, style: const TextStyle(color: Colors.black45, fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _value(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black45, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN': return 'Open';
      case 'PARTIALLY_FILLED': return 'Partially filled';
      case 'FILLED': return 'Completed';
      case 'CANCELLED': return 'Cancelled';
      case 'REJECTED': return 'Rejected';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'FILLED': return AppConfig.gainColor;
      case 'CANCELLED':
      case 'REJECTED': return AppConfig.lossColor;
      default: return AppConfig.neutralColor;
    }
  }
}
