import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/portfolio_position.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';

class HoldingsTab extends StatelessWidget {
  const HoldingsTab({
    super.key,
    required this.positions,
    required this.stocks,
    required this.onStockTap,
  });

  final Map<String, PortfolioPosition> positions;
  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  StockQuote? _findStock(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) {
        return stock;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final positionList = positions.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));

    if (positionList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 64,
                color: Colors.black38,
              ),
              SizedBox(height: 16),
              Text(
                'No holdings',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Your holdings will appear here after you buy stocks.',
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
      itemCount: positionList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final position = positionList[index];
        final stock = _findStock(position.symbol);

        final currentPrice = stock?.price ?? position.averageCost;
        final marketValue = position.marketValue(currentPrice);
        final profitLoss = position.unrealizedProfitLoss(currentPrice);
        final returnPercent = position.returnPercent(currentPrice);

        final profitColor = profitLoss > 0
            ? AppConfig.gainColor
            : profitLoss < 0
            ? AppConfig.lossColor
            : AppConfig.neutralColor;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: stock == null
                ? null
                : () {
                    onStockTap(stock);
                  },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      StockLogo(symbol: position.symbol, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              position.symbol,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${position.quantity} shares',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPrice(marketValue),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profitLoss > 0
                                ? '+'
                                : profitLoss < 0
                                ? '-'
                                : ''}'
                            '${formatPrice(profitLoss.abs())}',
                            style: TextStyle(
                              color: profitColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _valueItem(
                          'Avg. Price',
                          formatPrice(position.averageCost),
                        ),
                      ),
                      Expanded(
                        child: _valueItem('LTP', formatPrice(currentPrice)),
                      ),
                      Expanded(
                        child: _valueItem(
                          'Return',
                          '${returnPercent > 0 ? '+' : ''}'
                              '${returnPercent.toStringAsFixed(2)}%',
                          valueColor: profitColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _valueItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
