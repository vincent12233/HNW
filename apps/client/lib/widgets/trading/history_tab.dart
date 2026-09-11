import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/trading_order.dart';
import '../../utils/number_formatters.dart';
import 'standard_order_details_sheet.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key, required this.orders});

  final List<TradingOrder> orders;

  @override
  Widget build(BuildContext context) {
    final history = orders
        .where(
          (order) =>
              order.status == 'FILLED' ||
              order.status == 'CANCELLED' ||
              order.status == 'REJECTED',
        )
        .toList();

    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: Colors.black38),
              SizedBox(height: 16),
              AppText(
                'No order history',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              AppText(
                'Completed and cancelled orders will appear here.',
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
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = history[index];
        final sideColor = order.isBuy
            ? AppConfig.gainColor
            : AppConfig.lossColor;
        final statusColor = switch (order.status) {
          'FILLED' => AppConfig.gainColor,
          'CANCELLED' => AppConfig.neutralColor,
          'REJECTED' => AppConfig.lossColor,
          _ => AppConfig.neutralColor,
        };
        final displayPrice = order.limitPrice ?? order.price;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showStandardOrderDetails(context, order: order),
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
                          const SizedBox(height: 3),
                          AppText(
                            '${order.type == 'LIMIT' ? 'Limit Order' : 'Market Order'} • ${order.timeInForce}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: AppText(
                        _statusLabel(order.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: Colors.black38,
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(child: _value('Quantity', '${order.quantity}')),
                    Expanded(
                      child: _value(
                        order.isLimit ? 'Limit Price' : 'Execution Price',
                        displayPrice > 0 ? formatPrice(displayPrice) : '--',
                      ),
                    ),
                    Expanded(
                      child: _value(
                        'Filled Quantity',
                        '${order.filledQuantity}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppText(
                    order.formattedTime,
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String status) {
    switch (status) {
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
