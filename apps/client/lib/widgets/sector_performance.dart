import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';

class SectorPerformance extends StatelessWidget {
  const SectorPerformance({super.key, required this.stocks});

  final List<StockQuote> stocks;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StockQuote>>{};
    for (final stock in stocks) {
      final category = stock.category?.trim();
      if (category == null || category.isEmpty) continue;
      grouped.putIfAbsent(category, () => <StockQuote>[]).add(stock);
    }
    final sectors = grouped.entries.map((entry) {
      final change =
          entry.value.fold<double>(0, (total, stock) => total + stock.change) /
          entry.value.length;
      return (name: entry.key, change: change, count: entry.value.length);
    }).toList()..sort((left, right) => right.count.compareTo(left.count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Sector Performance',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: sectors.map((sector) {
            final change = sector.change;

            final color = change > 0
                ? AppConfig.gainColor
                : change < 0
                ? AppConfig.lossColor
                : AppConfig.neutralColor;

            return Container(
              width: 210,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.category_outlined, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          sector.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          '${change > 0 ? '+' : ''}'
                          '${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppText(
                          '${sector.count} stocks',
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
