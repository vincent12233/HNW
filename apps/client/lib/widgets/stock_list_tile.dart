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

  @override
  Widget build(BuildContext context) {
    final positive = stock.change >= 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE8EDF5))),
        ),
        child: Row(
          children: [
            StockLogo(
              symbol: stock.symbol,
              size: 40,
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
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
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
                    ],
                  ),
                  AppText(
                    stock.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AppText(
                    'Traded volume · ${formatVolume(stock.volume)}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                  if (!stock.quoteFresh) ...[
                    const SizedBox(height: 3),
                    const Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 11,
                          color: Color(0xFFF59E0B),
                        ),
                        SizedBox(width: 4),
                        AppText(
                          'Price delayed',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (positive ? AppConfig.gainColor : AppConfig.lossColor)
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: AppText(
                    '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: positive
                          ? AppConfig.gainColor
                          : AppConfig.lossColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  size: 21,
                  color: isFavorite ? Colors.amber : Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
