import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/pending_order.dart';
import '../../utils/number_formatters.dart';
import '../responsive_empty_state.dart';

class PendingOrdersTab extends StatelessWidget {
  const PendingOrdersTab({super.key, required this.orders, this.onCancel});

  final List<PendingOrder> orders;
  final ValueChanged<PendingOrder>? onCancel;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const ResponsiveEmptyState(
        icon: Icons.pending_actions_outlined,
        title: 'No pending orders',
        subtitle: 'Open orders waiting for execution will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];

        final sideColor = order.isBuy
            ? AppConfig.gainColor
            : AppConfig.lossColor;

        final orderType = order.orderType == PendingOrderType.market
            ? 'Market Order'
            : 'Limit Order';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConfig.borderColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: sideColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: AppText(
                      order.isBuy ? 'BUY' : 'SELL',
                      style: TextStyle(
                        color: sideColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          order.symbol,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppText(
                          order.exchange,
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const AppText(
                      'PENDING',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _value('Order Quantity', '${order.quantity}'),
                  ),
                  Expanded(
                    child: _value('Order Price', formatPrice(order.price)),
                  ),
                  Expanded(child: _value('Order Type', orderType)),
                ],
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      onCancel!(order);
                    },
                    child: const AppText('Cancel Order'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _value(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        AppText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
