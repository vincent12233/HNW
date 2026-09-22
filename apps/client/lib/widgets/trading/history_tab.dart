import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/trading_order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_page_scaffold.dart';
import 'order_card.dart';

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.orders, this.onRefresh});

  final List<TradingOrder> orders;
  final Future<void> Function()? onRefresh;

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String status = 'ALL';
  String side = 'ALL';

  List<TradingOrder> get _history {
    final rows = widget.orders.where((order) {
      final terminal =
          order.status == 'FILLED' ||
          order.status == 'CANCELLED' ||
          order.status == 'REJECTED';
      if (!terminal) return false;
      final matchesStatus = status == 'ALL' || order.status == status;
      final matchesSide =
          side == 'ALL' ||
          (side == 'BUY' && order.isBuy) ||
          (side == 'SELL' && !order.isBuy);
      return matchesStatus && matchesSide;
    }).toList()
      ..sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final allHistory = widget.orders.where(
      (order) =>
          order.status == 'FILLED' ||
          order.status == 'CANCELLED' ||
          order.status == 'REJECTED',
    );
    if (allHistory.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No order history',
        message: 'Completed, cancelled, and rejected orders will appear here.',
      );
    }

    final filtered = _history;
    return Column(
      children: [
        _chips(
          const [
            ('ALL', 'All'),
            ('FILLED', 'Filled'),
            ('CANCELLED', 'Cancelled'),
            ('REJECTED', 'Rejected'),
          ],
          status,
          (value) => setState(() => status = value),
          group: 'history-status',
        ),
        const SizedBox(height: AppSpacing.xs),
        _chips(
          const [
            ('ALL', 'All sides'),
            ('BUY', 'BUY'),
            ('SELL', 'SELL'),
          ],
          side,
          (value) => setState(() => side = value),
          group: 'history-side',
        ),
        if (status != 'ALL' || side != 'ALL')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                status = 'ALL';
                side = 'ALL';
              }),
              child: const AppText('Clear filters'),
            ),
          ),
        Expanded(
          child: AppStatusSwitch(
            switchKey: '$status|$side|${filtered.length}',
            child: filtered.isEmpty
                ? const AppEmptyState(
                    icon: Icons.filter_alt_outlined,
                    title: 'No matching history',
                    message:
                        'Nothing in the currently loaded orders matches these filters.',
                  )
                : ListView.separated(
                    padding: AppSpacing.page,
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) => OrderCard(
                      order: filtered[index],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chips(
    List<(String, String)> items,
    String selected,
    ValueChanged<String> onSelect, {
    required String group,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final item in items)
            ChoiceChip(
              key: ValueKey('order-filter-$group-${item.$1}'),
              label: AppText(item.$2),
              selected: selected == item.$1,
              selectedColor: AppColors.brandPrimary,
              backgroundColor: AppColors.surface,
              labelStyle: AppTypography.labelMedium.copyWith(
                color: selected == item.$1
                    ? AppColors.textInverse
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: selected == item.$1
                    ? AppColors.brandPrimary
                    : AppColors.border,
              ),
              onSelected: (_) => onSelect(item.$1),
            ),
        ],
      ),
    );
  }
}
