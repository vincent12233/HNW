import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../utils/number_formatters.dart';
import 'stock_logo.dart';

class MostActive extends StatelessWidget {
  const MostActive({super.key, required this.stocks, required this.onStockTap});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  String _formatVolume(int volume) {
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(2)}Cr';
    }

    if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(2)}L';
    }

    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)}K';
    }

    return volume.toString();
  }

  @override
  Widget build(BuildContext context) {
    final activeStocks = [...stocks]
      ..sort((a, b) => b.volume.compareTo(a.volume));

    final topStocks = activeStocks
        .where((stock) => stock.volume > 0)
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: AppText(
                'Most Active',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            AppText(
              'By volume',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (topStocks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const AppText(
              'Market volume data unavailable',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: topStocks.asMap().entries.map((entry) {
                final index = entry.key;
                final stock = entry.value;

                final changeColor = stock.change > 0
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
                            StockLogo(
                              symbol: stock.symbol,
                              size: 38,
                              logoUrl: stock.logoUrl,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    stock.symbol,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  AppText(
                                    'Vol ${_formatVolume(stock.volume)}',
                                    style: const TextStyle(
                                      color: Colors.black45,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AppText(
                                  formatPrice(stock.price),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                AppText(
                                  '${stock.change > 0 ? '+' : ''}'
                                  '${stock.change.toStringAsFixed(2)}%',
                                  style: TextStyle(
                                    color: changeColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (index != topStocks.length - 1)
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
