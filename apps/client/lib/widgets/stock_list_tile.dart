import '../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../utils/number_formatters.dart';
import 'stock_logo.dart';

class StockListTile extends StatelessWidget {
  const StockListTile({
    super.key,
    required this.stock,
    required this.onTap,
    this.isFavorite = false,
    this.onFavorite,
    this.onLogoLoadFailed,
  });

  final StockQuote stock;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onLogoLoadFailed;

  double? get _absoluteChange {
    if (stock.previousClose != null && stock.previousClose! > 0) {
      return stock.price - stock.previousClose!;
    }
    if (stock.change == 0 || stock.price <= 0) return null;
    final previous = stock.price / (1 + stock.change / 100);
    if (previous <= 0) return null;
    return stock.price - previous;
  }

  @override
  Widget build(BuildContext context) {
    final positive = stock.change >= 0;
    final changeColor = positive ? AppConfig.gainColor : AppConfig.lossColor;
    final absolute = _absoluteChange;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
        ),
        child: Row(
          children: [
            StockLogo(
              symbol: stock.symbol,
              size: 36,
              logoUrl: stock.logoUrl,
              onLoadFailed: onLogoLoadFailed,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: AppText(
                          stock.symbol,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: AppText(
                          stock.exchange,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!stock.quoteFresh) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    stock.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  formatPrice(stock.price),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                AppText(
                  absolute == null
                      ? '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%'
                      : '${formatSignedPrice(absolute)}  (${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%)',
                  style: TextStyle(
                    color: changeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: isFavorite ? Colors.amber : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
