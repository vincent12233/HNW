import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/trading_order.dart';
import '../../utils/number_formatters.dart';
import 'standard_order_details_sheet.dart';
import '../responsive_empty_state.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.orders, this.onCancel});

  final List<TradingOrder> orders;
  final Future<String?> Function(TradingOrder order)? onCancel;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String query = '';
  String status = 'ALL';

  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) {
      return const ResponsiveEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders',
        subtitle: 'Your order activity will appear here.',
      );
    }

    final filtered = widget.orders.where((order) {
      final needle = query.toLowerCase();
      final matchesQuery =
          needle.isEmpty ||
          order.symbol.toLowerCase().contains(needle) ||
          order.exchange.toLowerCase().contains(needle) ||
          (order.orderId?.toLowerCase().contains(needle) ?? false);
      return matchesQuery && (status == 'ALL' || order.status == status);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            onChanged: (value) => setState(() => query = value.trim()),
            decoration: const InputDecoration(
              hintText: 'Search symbol or order ID',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children:
                [
                      'ALL',
                      'OPEN',
                      'PARTIALLY_FILLED',
                      'FILLED',
                      'CANCELLED',
                      'REJECTED',
                    ]
                    .map(
                      (value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: AppText(
                            value == 'ALL' ? 'All' : _statusLabel(value),
                          ),
                          selected: status == value,
                          labelStyle: TextStyle(
                            color: status == value
                                ? Colors.white
                                : AppConfig.textPrimaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => status = value),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: AppText('No matching orders'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    final sideColor = order.isBuy
                        ? AppConfig.gainColor
                        : AppConfig.lossColor;
                    final displayPrice = order.limitPrice ?? order.price;

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => showStandardOrderDetails(
                        context,
                        order: order,
                        onCancel: order.isActive ? widget.onCancel : null,
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
                                Flexible(
                                  child: Container(
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
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    color: _statusColor(
                                      order.status,
                                    ).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: AppText(
                                    _statusLabel(order.status),
                                    style: TextStyle(
                                      color: _statusColor(order.status),
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
                                Expanded(
                                  child: _value(
                                    'Quantity',
                                    '${order.quantity}',
                                  ),
                                ),
                                Expanded(
                                  child: _value(
                                    order.isLimit
                                        ? 'Limit Price'
                                        : 'Execution Price',
                                    displayPrice > 0
                                        ? formatPrice(displayPrice)
                                        : '--',
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
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppText(
                                order.formattedTime,
                                style: const TextStyle(
                                  color: Colors.black45,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'PARTIALLY_FILLED':
        return 'Partially filled';
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
      case 'PARTIALLY_FILLED':
        return const Color(0xFFF59E0B);
      case 'OPEN':
        return AppConfig.primaryColor;
      case 'CANCELLED':
      case 'REJECTED':
        return AppConfig.lossColor;
      default:
        return AppConfig.neutralColor;
    }
  }
}
