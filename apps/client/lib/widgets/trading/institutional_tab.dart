import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/institutional_opportunity.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';
import 'product_offer_card.dart';
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
        return ProductOfferCard(
          name: stock.companyName,
          symbol: stock.symbol,
          type: 'Ins. Stock',
          marketPrice: stock.marketPrice > 0 ? stock.marketPrice : (live ? quote.price : 0),
          offerPrice: stock.price,
          actionLabel: onOpen == null ? 'View details' : 'Trade Now',
          onTrade: () {
            if (onOpen != null && live) {
              onOpen!(stock);
              return;
            }
            showDialog<void>(context: context, builder: (context) => AlertDialog(
              title: AppText(stock.companyName),
              content: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppText('${stock.symbol} · ${stock.exchange}'),
                const SizedBox(height: 16),
                AppText('Offer Price: ${formatPrice(stock.price)}'),
                if (!live) const AppText('Live quote unavailable'),
              ]),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const AppText('Close'))],
            ));
          },
        );      },
    );
  }
}


