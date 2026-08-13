import 'package:flutter/material.dart';

import '../../models/institutional_opportunity.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';

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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 64,
                color: Colors.black38,
              ),
              SizedBox(height: 16),
              Text(
                'No institutional stocks available',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Institutional stock opportunities will appear here when available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
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
          if (item.symbol.toUpperCase() == stock.symbol.toUpperCase()) {
            quote = item;
            break;
          }
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  StockLogo(symbol: stock.symbol, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stock.symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stock.companyName,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    quote != null && quote.quoteFresh
                        ? formatPrice(quote.price)
                        : '--',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Backend institutional offer',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                  if (onOpen != null && quote != null && quote.quoteFresh)
                    FilledButton(
                      onPressed: () => onOpen!(stock),
                      child: const Text('View'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
