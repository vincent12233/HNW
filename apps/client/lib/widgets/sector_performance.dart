import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';

class SectorPerformance extends StatelessWidget {
  const SectorPerformance({super.key, required this.stocks});

  final List<StockQuote> stocks;

  double _averageChange(List<String> symbols) {
    final matched = stocks
        .where((stock) => symbols.contains(stock.symbol))
        .toList();

    if (matched.isEmpty) {
      return 0;
    }

    final total = matched.fold<double>(0, (sum, stock) => sum + stock.change);

    return total / matched.length;
  }

  @override
  Widget build(BuildContext context) {
    final sectors = [
      (
        name: 'Banking',
        icon: Icons.account_balance_outlined,
        change: _averageChange(['HDFCBANK', 'ICICIBANK']),
      ),
      (
        name: 'IT',
        icon: Icons.memory_outlined,
        change: _averageChange(['TCS', 'INFY']),
      ),
      (
        name: 'Energy',
        icon: Icons.bolt_outlined,
        change: _averageChange(['RELIANCE']),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
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
                    child: Icon(sector.icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sector.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${change > 0 ? '+' : ''}'
                          '${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
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
