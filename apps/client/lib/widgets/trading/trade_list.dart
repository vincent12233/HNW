import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/stock_quote.dart';
import '../../models/portfolio_position.dart';
import '../../services/trading_service.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import '../../models/trading_order.dart';
import 'standard_order_details_sheet.dart';

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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Trading Summary',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 18),
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
                                  AppConfig.textPrimaryColor,
                                ),
                              ),
                              Expanded(
                                child: _summary(
                                  'Total Invested',
                                  formatPrice(invested),
                                  AppConfig.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: _summary(
                                  'Unrealized P&L',
                                  '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                                  pnl >= 0
                                      ? AppConfig.gainColor
                                      : AppConfig.lossColor,
                                ),
                              ),
                              Expanded(
                                child: _summary(
                                  'Available Funds',
                                  account == null
                                      ? '--'
                                      : formatPrice(account!.availableBalance),
                                  AppConfig.textPrimaryColor,
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
                              AppConfig.textPrimaryColor,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _summary(
                              'Total Invested',
                              formatPrice(invested),
                              AppConfig.textPrimaryColor,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _summary(
                              'Unrealized P&L',
                              '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                              pnl >= 0
                                  ? AppConfig.gainColor
                                  : AppConfig.lossColor,
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: _summary(
                              'Available Funds',
                              account == null
                                  ? '--'
                                  : formatPrice(account!.availableBalance),
                              AppConfig.textPrimaryColor,
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
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(
              child: AppText(
                'Recent Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
            padding: EdgeInsets.symmetric(vertical: 20),
            child: AppText('No orders yet'),
          ),
        ...orders
            .take(4)
            .map(
              (order) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  order.isBuy ? Icons.call_received : Icons.call_made,
                  color: order.isBuy
                      ? AppConfig.gainColor
                      : AppConfig.lossColor,
                ),
                title: AppText(
                  order.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: AppText(
                  '${order.exchange} · ${order.quantity} · ${tr(order.status)}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showStandardOrderDetails(
                  context,
                  order: order,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: positions.isEmpty
                  ? null
                  : () => _showAllPositions(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const AppText(
                'View All',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppConfig.dividerColor),
          ),
          child: positions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: AppText(
                      'No open positions',
                      style: TextStyle(color: AppConfig.textSecondaryColor),
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
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(
              child: AppText(
                'Total Holdings Value',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            AppText(
              formatPrice(holdings),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: AppText(
            '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
            style: TextStyle(
              color: pnl >= 0 ? AppConfig.gainColor : AppConfig.lossColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: AppText(
                '${tr('Open Holdings')} (${positions.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppConfig.dividerColor)),
        ),
        child: Row(
          children: [
            StockLogo(symbol: position.symbol, size: 36),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    position.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  AppText(
                    '${position.quantity} Shares · ${position.exchange}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppConfig.textSecondaryColor,
                    ),
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AppText(
                    'Avg. ${formatPrice(position.averageCost)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppConfig.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: pnl >= 0
                          ? AppConfig.gainColor
                          : AppConfig.lossColor,
                    ),
                  ),
                  AppText(
                    '${pnl >= 0 ? '+' : ''}${position.averageCost > 0 ? (pnl / (position.averageCost * position.quantity) * 100).toStringAsFixed(2) : '0.00'}%',
                    style: TextStyle(
                      fontSize: 9,
                      color: pnl >= 0
                          ? AppConfig.gainColor
                          : AppConfig.lossColor,
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
        AppText(
          label,
          maxLines: 2,
          style: const TextStyle(color: AppConfig.textSecondaryColor, fontSize: 11),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AppText(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
