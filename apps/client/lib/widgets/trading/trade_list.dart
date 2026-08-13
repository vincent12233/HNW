import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/stock_quote.dart';
import '../../models/portfolio_position.dart';
import '../../services/trading_service.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';

class TradeList extends StatelessWidget {
  const TradeList({
    super.key,
    required this.stocks,
    required this.positions,
    required this.account,
    required this.onTrade,
  });

  final List<StockQuote> stocks;
  final Map<String, PortfolioPosition> positions;
  final TradingAccountSnapshot? account;
  final ValueChanged<StockQuote> onTrade;

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
    final total = (account?.cashBalance ?? 0) + holdings;
    final pnl = holdings - invested;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Trading Summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.visibility_outlined, size: 17),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _summary(
                        'Total Portfolio Value',
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
                    Expanded(
                      child: _summary(
                        'Total P&L',
                        '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                        pnl >= 0 ? AppConfig.gainColor : AppConfig.lossColor,
                      ),
                    ),
                    Expanded(
                      child: _summary(
                        'Available Balance',
                        formatPrice(account?.cashBalance ?? 0),
                        AppConfig.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: ['All', 'Inst.', 'OTC', 'IPO']
              .asMap()
              .entries
              .map(
                (entry) => Container(
                  margin: const EdgeInsets.only(right: 9),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 17,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: entry.key == 0
                        ? AppConfig.primaryColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: entry.key == 0
                          ? AppConfig.primaryColor
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: entry.key == 0
                          ? Colors.white
                          : const Color(0xFF334155),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              'Open Positions (${positions.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Text(
              'View All',
              style: TextStyle(
                color: AppConfig.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE8EDF5)),
          ),
          child: positions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No open positions',
                      style: TextStyle(color: Color(0xFF64748B)),
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
        const SizedBox(height: 18),
        const Row(
          children: [
            Text(
              'Market Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Spacer(),
            Text(
              'View More',
              style: TextStyle(
                color: AppConfig.primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            _indexMini('NIFTY 50', '24,467.45', .91),
            const SizedBox(width: 7),
            _indexMini('SENSEX', '80,159.83', .90),
            const SizedBox(width: 7),
            _indexMini('BANK NIFTY', '51,356.80', 1.01),
            const SizedBox(width: 7),
            _indexMini('INDIA VIX', '12.85', -1.16),
          ],
        ),
        const SizedBox(height: 12),
      ],
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
          border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
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
                  Text(
                    position.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${position.quantity} Shares · ${position.exchange}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
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
                  Text(
                    formatPrice(price),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Avg. ${formatPrice(position.averageCost)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
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
                  Text(
                    '${pnl >= 0 ? '+' : ''}${formatPrice(pnl)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: pnl >= 0
                          ? AppConfig.gainColor
                          : AppConfig.lossColor,
                    ),
                  ),
                  Text(
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

  Widget _indexMini(String name, String value, double change) => Expanded(
    child: Container(
      height: 94,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 9,
              color: change >= 0 ? AppConfig.gainColor : AppConfig.lossColor,
            ),
          ),
          const Spacer(),
          Container(
            height: 2,
            color: (change >= 0 ? AppConfig.gainColor : AppConfig.lossColor)
                .withValues(alpha: .7),
          ),
        ],
      ),
    ),
  );

  Widget _summary(String label, String value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.tag,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String tag;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }
}
