import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/stock_quote.dart';
import '../../models/portfolio_position.dart';
import '../../services/trading_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import '../../models/trading_order.dart';
import 'order_card.dart';

class TradeList extends StatelessWidget {
  const TradeList({
    super.key,
    required this.stocks,
    required this.positions,
    required this.account,
    required this.onTrade,
    required this.indexQuotes,
    required this.onViewMarkets,
    this.orders = const [],
    this.onViewOrders,
    this.onCancel,
  });

  final List<StockQuote> stocks;
  final Map<String, PortfolioPosition> positions;
  final TradingAccountSnapshot? account;
  final ValueChanged<StockQuote> onTrade;
  final Map<String, (double, double)> indexQuotes;
  final VoidCallback onViewMarkets;
  final List<TradingOrder> orders;
  final VoidCallback? onViewOrders;
  final Future<String?> Function(TradingOrder)? onCancel;

  @override
  Widget build(BuildContext context) {
    final invested = positions.values.fold<double>(
      0,
      (sum, position) => sum + position.averageCost * position.quantity,
    );
    final holdings = positions.values.fold<double>(0, (sum, position) {
      final quote = stocks.where(
        (item) =>
            item.symbol == position.symbol &&
            item.exchange == position.exchange,
      );
      return sum +
          position.marketValue(
            quote.isEmpty ? position.averageCost : quote.first.price,
          );
    });
    final total = holdings;
    final pnl = holdings - invested;
    return SingleChildScrollView(
      key: const Key('trade-overview'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm - 2,
        AppSpacing.lg,
        AppSpacing.lg + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    'Trading Summary',
                    style: AppTypography.titleMedium.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: AppSpacing.lg + 2),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 380;
                      if (compact) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _summary(
                                    'Trading Positions Value',
                                    formatPrice(total),
                                    AppColors.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: _summary(
                                    'Total Invested',
                                    formatPrice(invested),
                                    AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg + 2),
                            Row(
                              children: [
                                Expanded(
                                  child: _summary(
                                    'Unrealized P&L',
                                    '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                                    pnl >= 0 ? AppColors.gain : AppColors.loss,
                                  ),
                                ),
                                Expanded(
                                  child: _summary(
                                    'Available Funds',
                                    account == null
                                        ? '--'
                                        : formatPrice(
                                            account!.availableBalance,
                                          ),
                                    AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _summary(
                                'Trading Positions Value',
                                formatPrice(total),
                                AppColors.textPrimary,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _summary(
                                'Total Invested',
                                formatPrice(invested),
                                AppColors.textPrimary,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _summary(
                                'Unrealized P&L',
                                '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                                pnl >= 0 ? AppColors.gain : AppColors.loss,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _summary(
                                'Available Funds',
                                account == null
                                    ? '--'
                                    : formatPrice(account!.availableBalance),
                                AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Recent Orders',
                  style: AppTypography.sectionTitle,
                ),
              ),
              if (onViewOrders != null)
                TextButton(
                  onPressed: onViewOrders,
                  child: const AppText('View All'),
                ),
            ],
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText('No orders yet'),
                  SizedBox(height: AppSpacing.xs),
                  AppText(
                    'Submitted orders will appear here. This list is empty.',
                  ),
                ],
              ),
            )
          else
            ...orders.take(4).map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OrderCard(
                  order: order,
                  compact: true,
                  onCancel: onCancel,
                ),
              ),
            ),
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: AppText(
                  '${tr('Open Holdings')} (${positions.length})',
                  style: AppTypography.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: positions.isEmpty
                    ? null
                    : () => _showAllPositions(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                ),
                child: AppText(
                  'View All',
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 1),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.divider),
            ),
            child: positions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Center(
                      child: AppText(
                        'No open positions. Holdings appear after a fill.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: positions.values
                        .take(5)
                        .map((position) => _positionRow(position))
                        .toList(),
                  ),
          ),
          const Divider(height: AppSpacing.xxl),
          Row(
            children: [
              Expanded(
                child: AppText(
                  'Total Holdings Value',
                  style: AppTypography.titleSmall,
                ),
              ),
              AppText(
                formatPrice(holdings),
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Align(
            alignment: Alignment.centerRight,
            child: AppText(
              '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
              style: AppTypography.bodyMedium.copyWith(
                color: pnl >= 0 ? AppColors.gain : AppColors.loss,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  void _showAllPositions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .45,
        maxChildSize: .92,
        builder: (context, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm + 2,
              ),
              child: AppText(
                '${tr('Open Holdings')} (${positions.length})',
                style: AppTypography.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: positions.length,
                itemBuilder: (context, index) =>
                    _positionRow(positions.values.elementAt(index)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionRow(PortfolioPosition position) {
    final quote = stocks.where(
      (item) =>
          item.symbol == position.symbol && item.exchange == position.exchange,
    );
    final price = quote.isEmpty ? position.averageCost : quote.first.price;
    final pnl = position.unrealizedProfitLoss(price);
    return InkWell(
      onTap: quote.isEmpty ? null : () => onTrade(quote.first),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            StockLogo(symbol: position.symbol, size: 36),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    position.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  AppText(
                    '${position.quantity} Shares · ${position.exchange}',
                    style: AppTypography.caption.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    formatPrice(price),
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTypography.tabularFeatures,
                    ),
                  ),
                  AppText(
                    'Avg. ${formatPrice(position.averageCost)}',
                    style: AppTypography.caption.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pnl >= 0 ? AppColors.gain : AppColors.loss,
                      fontFeatures: AppTypography.tabularFeatures,
                    ),
                  ),
                  AppText(
                    '${pnl >= 0 ? '+' : ''}${position.averageCost > 0 ? (pnl / (position.averageCost * position.quantity) * 100).toStringAsFixed(2) : '0.00'}%',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: pnl >= 0 ? AppColors.gain : AppColors.loss,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, maxLines: 2, style: AppTypography.caption),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AppText(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: AppTypography.tabularFeatures,
            ),
          ),
        ),
      ],
    ),
  );
}
