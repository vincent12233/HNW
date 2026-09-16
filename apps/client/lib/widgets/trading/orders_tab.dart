import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/trading_order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../../utils/order_status_presentation.dart';
import '../app_chip.dart';
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                        padding: const EdgeInsets.only(right: AppSpacing.sm),
                        child: ChoiceChip(
                          label: AppText(
                            value == 'ALL'
                                ? 'All'
                                : OrderStatusPresentation.label(value),
                          ),
                          selected: status == value,
                          selectedColor: AppColors.brandPrimary,
                          backgroundColor: AppColors.surface,
                          labelStyle: AppTypography.labelMedium.copyWith(
                            color: status == value
                                ? AppColors.textInverse
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: status == value
                                ? AppColors.brandPrimary
                                : AppColors.border,
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
                  padding: AppSpacing.page,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    final sideColor = OrderStatusPresentation.sideColor(
                      order.isBuy ? 'BUY' : 'SELL',
                    );
                    final displayPrice = order.limitPrice ?? order.price;

                    return InkWell(
                      borderRadius: AppRadius.borderLg,
                      onTap: () => showStandardOrderDetails(
                        context,
                        order: order,
                        onCancel: order.isActive ? widget.onCancel : null,
                      ),
                      child: Container(
                        padding: AppSpacing.card,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: AppRadius.borderLg,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm + 2,
                                      vertical: AppSpacing.xs + 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: sideColor.withValues(alpha: 0.10),
                                      borderRadius: AppRadius.borderSm,
                                    ),
                                    child: AppText(
                                      OrderStatusPresentation.sideLabel(
                                        order.isBuy ? 'BUY' : 'SELL',
                                      ),
                                      style: AppTypography.labelSmall.copyWith(
                                        color: sideColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm + 2),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        order.symbol,
                                        style: AppTypography.titleMedium
                                            .copyWith(fontSize: 17),
                                      ),
                                      AppText(
                                        order.exchange,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textTertiary,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      AppText(
                                        '${order.type == 'LIMIT' ? 'Limit Order' : 'Market Order'} • ${order.timeInForce}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                AppStatusChip(
                                  label: OrderStatusPresentation.label(
                                    order.status,
                                  ),
                                  variant: OrderStatusPresentation.chipVariant(
                                    order.status,
                                  ),
                                  compact: true,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 20,
                                  color: AppColors.textDisabled,
                                ),
                              ],
                            ),
                            const Divider(height: AppSpacing.xxl),
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
                            const SizedBox(height: AppSpacing.md + 2),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: AppText(
                                order.formattedTime,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textTertiary,
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
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppText(
          value,
          style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
