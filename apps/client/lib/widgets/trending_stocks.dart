import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../utils/number_formatters.dart';
import 'stock_logo.dart';

class TrendingStocks extends StatelessWidget {
  const TrendingStocks({
    super.key,
    required this.stocks,
    required this.onStockTap,
  });

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  @override
  Widget build(BuildContext context) {
    final trending = List<StockQuote>.from(stocks)
      ..sort((a, b) => b.volume.compareTo(a.volume));

    final displayStocks = trending
        .where((stock) => stock.volume > 0)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.local_fire_department_outlined, size: 22),
            SizedBox(width: 8),
            AppText(
              'Trending Stocks',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppConfig.borderColor),
          ),
          child: displayStocks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: AppText(
                    'Market activity data unavailable',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : Column(
                  children: displayStocks.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final stock = entry.value;

                    final color = stock.change > 0
                        ? AppConfig.gainColor
                        : stock.change < 0
                        ? AppConfig.lossColor
                        : AppConfig.neutralColor;

                    return Column(
                      children: [
                        InkWell(
                          onTap: () => onStockTap(stock),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: AppText(
                                    '$rank',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppConfig.textSecondaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                StockLogo(
                                  symbol: stock.symbol,
                                  size: 42,
                                  logoUrl: stock.logoUrl,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                        stock.symbol,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AppText(
                                        stock.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      AppText(
                                        'Volume ${formatVolume(stock.volume)}',
                                        style: const TextStyle(
                                          color: Colors.black45,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    AppText(
                                      formatPrice(stock.price),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          stock.change > 0
                                              ? Icons.arrow_upward
                                              : stock.change < 0
                                              ? Icons.arrow_downward
                                              : Icons.remove,
                                          size: 14,
                                          color: color,
                                        ),
                                        const SizedBox(width: 2),
                                        AppText(
                                          '${stock.change > 0 ? '+' : ''}'
                                          '${stock.change.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (rank != displayStocks.length)
                          const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
