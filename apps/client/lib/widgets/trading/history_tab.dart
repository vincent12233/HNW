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
      return const ResponsiveEmptyState(
        icon: Icons.history,
        title: 'No order history',
        subtitle: 'Completed and cancelled orders will appear here.',
      );
    }

    return ListView.separated(
      padding: AppSpacing.page,
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final order = history[index];
        final sideColor = OrderStatusPresentation.sideColor(
          order.isBuy ? 'BUY' : 'SELL',
        );
        final displayPrice = order.limitPrice ?? order.price;

        return InkWell(
          borderRadius: AppRadius.borderLg,
          onTap: () => showStandardOrderDetails(context, order: order),
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
                    Container(
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
                    const SizedBox(width: AppSpacing.sm + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            order.symbol,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 17,
                            ),
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
                      label: OrderStatusPresentation.label(order.status),
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
                const SizedBox(height: AppSpacing.md),
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
