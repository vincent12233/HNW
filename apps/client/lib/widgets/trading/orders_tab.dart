import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/trading_order.dart';
import '../../services/app_content_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../app_feedback.dart';
import '../app_page_scaffold.dart';
import 'order_card.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({
    super.key,
    required this.orders,
    this.onCancel,
    this.loading = false,
    this.failed = false,
    this.onRefresh,
  });

  final List<TradingOrder> orders;
  final Future<String?> Function(TradingOrder order)? onCancel;
  final bool loading;
  final bool failed;
  final Future<void> Function()? onRefresh;

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String query = '';
  String status = 'ALL';
  String side = 'ALL';
  var _refreshing = false;

  @override
  void initState() {
    super.initState();
    AppContentService.instance.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppContentService.instance.removeListener(_onContentChanged);
    super.dispose();
  }

  List<TradingOrder> get _filtered {
    final needle = query.toLowerCase();
    final rows = widget.orders.where((order) {
      final matchesQuery =
          needle.isEmpty ||
          order.symbol.toLowerCase().contains(needle) ||
          order.exchange.toLowerCase().contains(needle) ||
          (order.orderId?.toLowerCase().contains(needle) ?? false);
      final matchesSide =
          side == 'ALL' ||
          (side == 'BUY' && order.isBuy) ||
          (side == 'SELL' && !order.isBuy);
      final matchesStatus = switch (status) {
        'ALL' => true,
        'OPEN_PENDING' => order.status == 'OPEN' || order.status == 'PENDING',
        _ => order.status == status,
      };
      return matchesQuery && matchesSide && matchesStatus;
    }).toList();
    rows.sort((a, b) => b.placedAt.compareTo(a.placedAt));
    return rows;
  }

  Future<void> _refresh() async {
    final action = widget.onRefresh;
    if (action == null || _refreshing) return;
    setState(() => _refreshing = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.orders.isEmpty) {
      return const AppLoadingView(message: 'Loading orders');
    }
    if (widget.failed && widget.orders.isEmpty) {
      return AppErrorView(
        title: 'Orders could not be loaded',
        message:
            'The last refresh failed. Your previous orders were not removed.',
        onRetry: widget.onRefresh == null || _refreshing ? null : _refresh,
      );
    }
    if (widget.orders.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders',
        message:
            'Your order activity will appear here. No sample orders are shown.',
        action: widget.onRefresh == null
            ? null
            : IconButton(
                tooltip: 'Refresh orders',
                onPressed: _refreshing ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
      );
    }

    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => query = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Search symbol or order ID',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh orders',
                onPressed: widget.onRefresh == null || _refreshing
                    ? null
                    : _refresh,
                icon: _refreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        _chipRow(
          [
            ('ALL', 'All'),
            ('OPEN_PENDING', 'Open / Pending'),
            ('PARTIALLY_FILLED', 'Partially Filled'),
            ('FILLED', 'Filled'),
            ('CANCELLED', 'Cancelled'),
            ('REJECTED', 'Rejected'),
          ],
          status,
          (value) => setState(() => status = value),
          group: 'status',
        ),
        const SizedBox(height: AppSpacing.xs),
        _chipRow(
          const [('ALL', 'All sides'), ('BUY', 'BUY'), ('SELL', 'SELL')],
          side,
          (value) => setState(() => side = value),
          group: 'side',
        ),
        if (query.isNotEmpty || status != 'ALL' || side != 'ALL')
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                query = '';
                status = 'ALL';
                side = 'ALL';
              }),
              child: AppText(
                AppContentService.instance.current.text(
                  'trading',
                  'orders.clear_filters',
                  fallback: 'Clear filters',
                ),
              ),
            ),
          ),
        Expanded(
          child: AppStatusSwitch(
            switchKey: '$status|$side|$query|${filtered.length}',
            child: filtered.isEmpty
                ? const AppEmptyState(
                    icon: Icons.filter_alt_outlined,
                    title: 'No matching orders',
                    message:
                        'Nothing in the currently loaded orders matches these filters.',
                  )
                : RefreshIndicator(
                    onRefresh: widget.onRefresh == null
                        ? () async {}
                        : _refresh,
                    child: ListView.separated(
                      key: const Key('orders-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: AppSpacing.page,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        return OrderCard(
                          order: filtered[index],
                          onCancel: widget.onCancel,
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _chipRow(
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
