import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';

class MarketMovers extends StatelessWidget {
  const MarketMovers({
    super.key,
    required this.stocks,
    required this.onStockTap,
  });

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  @override
  Widget build(BuildContext context) {
    final gainers = [...stocks]..sort((a, b) => b.change.compareTo(a.change));

    final losers = [...stocks]..sort((a, b) => a.change.compareTo(b.change));

    final topGainers = gainers
        .where((stock) => stock.change > 0)
        .take(3)
        .toList();
    final topLosers = losers
        .where((stock) => stock.change < 0)
        .take(3)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Market Movers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MoverCard(
                title: 'Top Gainers',
                stocks: topGainers,
                positive: true,
                onStockTap: onStockTap,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MoverCard(
                title: 'Top Losers',
                stocks: topLosers,
                positive: false,
                onStockTap: onStockTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MoverCard extends StatelessWidget {
  const _MoverCard({
    required this.title,
    required this.stocks,
    required this.positive,
    required this.onStockTap,
  });

  final String title;
  final List<StockQuote> stocks;
  final bool positive;
  final ValueChanged<StockQuote> onStockTap;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppConfig.gainColor : AppConfig.lossColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            title,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (stocks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    size: 18,
                    color: color.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: AppText(
                      'No market data available',
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                ],
              ),
            )
          else
            ...stocks.map(
              (stock) => InkWell(
                onTap: () => onStockTap(stock),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppText(
                          stock.symbol,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      AppText(
                        '${stock.change > 0 ? '+' : ''}'
                        '${stock.change.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: stock.change > 0
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
