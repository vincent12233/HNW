import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../utils/number_formatters.dart';
import 'stock_logo.dart';

class StockListTile extends StatelessWidget {
  const StockListTile({
    super.key,
    required this.stock,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
  });

  final StockQuote stock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final positive = stock.change >= 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8EDF5)),
        ),
        child: Row(
          children: [
            StockLogo(symbol: stock.symbol, size: 42, logoUrl: stock.logoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    stock.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Volume ${formatVolume(stock.volume)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(stock.price),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: positive ? AppConfig.gainColor : AppConfig.lossColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: onFavorite,
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite ? Colors.amber : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
