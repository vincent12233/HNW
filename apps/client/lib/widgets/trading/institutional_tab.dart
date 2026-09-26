import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../models/institutional_opportunity.dart';
import '../../models/stock_quote.dart';
import '../../services/app_content_service.dart';
import '../../utils/number_formatters.dart';
import '../app_page_scaffold.dart';
import 'product_offer_card.dart';
import 'product_risk_notice.dart';
import 'trading_guide_card.dart';

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

  StockQuote? _quoteFor(InstitutionalStock stock) {
    for (final item in marketStocks) {
      if (item.symbol.toUpperCase() == stock.symbol.toUpperCase() &&
          item.exchange.toUpperCase() == stock.exchange.toUpperCase()) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppContentService.instance,
      builder: (context, _) {
        final content = AppContentService.instance.current;
        final guideTitle = content.title('trading', 'guide.institutional');
        final guideBody = content.text('trading', 'guide.institutional');

        if (stocks.isEmpty) {
          return Column(
            children: [
              if (guideBody.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TradingGuideCard(title: guideTitle, body: guideBody),
                ),
              Expanded(
                child: AppEmptyState(
                  icon: Icons.business_center_outlined,
                  title: content.text(
                    'trading',
                    'institutional.empty_title',
                    fallback: 'No institutional offers available',
                  ),
                  message: content.text(
                    'trading',
                    'institutional.empty_subtitle',
                    fallback:
                        'Stocks will appear here when live market data is available.',
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: stocks.length + (guideBody.isNotEmpty ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (guideBody.isNotEmpty && index == 0) {
              return TradingGuideCard(title: guideTitle, body: guideBody);
            }
            final stock = stocks[guideBody.isNotEmpty ? index - 1 : index];
            final quote = _quoteFor(stock);
            final live = quote != null && quote.quoteFresh;
            final settlementPrice = stock.price > 0
                ? stock.price
                : (live ? quote.price : 0.0);

            return ProductOfferCard(
              name: stock.companyName,
              symbol: stock.symbol,
              type: 'Ins. Stock',
              marketPrice: settlementPrice,
              offerPrice: settlementPrice,
              offerLabel: 'Live settlement',
              expectedReturn: stock.expectedReturn,
              actionLabel: onOpen == null ? 'View details' : 'Trade Now',
              onTrade: settlementPrice <= 0 && onOpen != null
                  ? null
                  : () {
                      if (onOpen != null && settlementPrice > 0) {
                        onOpen!(stock);
                        return;
                      }
                      showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: AppText(stock.companyName),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppText('${stock.symbol} · ${stock.exchange}'),
                              const SizedBox(height: 16),
                              AppText(
                                'Settlement price (live): ${formatPrice(settlementPrice)}',
                              ),
                              if (!live && settlementPrice <= 0)
                                const AppText('Live quote unavailable'),
                              const SizedBox(height: 16),
                              const ProductRiskNotice(),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const AppText('Close'),
                            ),
                          ],
                        ),
                      );
                    },
            );
          },
        );
      },
    );
  }
}
