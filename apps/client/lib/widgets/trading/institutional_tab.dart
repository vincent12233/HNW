import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/institutional_opportunity.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';
import '../responsive_empty_state.dart';

class InstitutionalTab extends StatelessWidget {
  const InstitutionalTab({
    super.key,
    required this.stocks,
    required this.marketStocks,
    this.onOpen,
  });

  final List<InstitutionalStock> stocks;
  final List<StockQuote> marketStocks;
  final ValueChanged<InstitutionalStock>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (stocks.isEmpty) {
      return const ResponsiveEmptyState(
        icon: Icons.business_center_outlined,
        title: 'No institutional offers available',
        subtitle: 'Stocks will appear here when live market data is available.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stock = stocks[index];
        StockQuote? quote;
        for (final item in marketStocks) {
          if (item.symbol.toUpperCase() == stock.symbol.toUpperCase() &&
              item.exchange.toUpperCase() == stock.exchange.toUpperCase()) {
            quote = item;
            break;
          }
        }

        final live = quote != null && quote.quoteFresh;
        final positive = (quote?.change ?? 0) >= 0;
        final changeColor = positive
            ? const Color(0xFF16A364)
            : const Color(0xFFDC3545);
        return Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpen != null && live ? () => onOpen!(stock) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
              child: Row(
                children: [
                  StockLogo(
                    symbol: stock.symbol,
                    logoUrl: quote?.logoUrl,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          stock.companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AppText(
                          '${stock.symbol} · ${stock.exchange}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                        if (!live)
                          const Padding(
                            padding: EdgeInsets.only(top: 3),
                            child: AppText(
                              'Live quote unavailable',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(
                        live ? formatPrice(quote.price) : '--',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        live
                            ? '${positive ? '+' : ''}${quote.change.toStringAsFixed(2)}%'
                            : '--',
                        style: TextStyle(
                          color: live ? changeColor : const Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (onOpen != null && live)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
