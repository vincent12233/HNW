import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';

class TradeList extends StatelessWidget {
  const TradeList({super.key, required this.stocks, required this.onTrade});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onTrade;

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) {
      return const Center(
        child: Text('No stocks available', style: TextStyle(fontSize: 18)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = stocks[index];
        final positive = stock.change >= 0;

        return Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stock.symbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stock.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatPrice(stock.price),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: positive
                            ? AppConfig.gainColor
                            : AppConfig.lossColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () {
                    onTrade(stock);
                  },
                  child: const Text('Trade'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
