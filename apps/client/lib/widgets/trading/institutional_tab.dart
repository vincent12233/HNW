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
                  StockLogo(
                    symbol: stock.symbol,
                    logoUrl: quote?.logoUrl,
                    size: 46,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${stock.companyName}\n(${stock.symbol}) ${stock.exchange}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
              const Divider(height: 22),
              _offerLine(
                Icons.trending_up_rounded,
                'Buy Direction',
                stock.direction == 'DOWN' ? 'Downward' : 'Upward',
                stock.direction == 'DOWN' ? Colors.red : Colors.green,
              ),
              const SizedBox(height: 9),
              _offerLine(
                Icons.payments_outlined,
                'Reference Buy Price',
                stock.referencePrice == null
                    ? 'Market Price'
                    : formatPrice(stock.referencePrice!),
                const Color(0xFF0F172A),
              ),
              const SizedBox(height: 9),
              _offerLine(
                Icons.auto_graph_rounded,
                'Expected Short-Term Return',
                stock.expectedReturn == null
                    ? '--'
                    : '${stock.expectedReturn!.toStringAsFixed(2)}%',
                Colors.green,
              ),
              if (stock.reason?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stock.reason!,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (onOpen != null && quote != null && quote.quoteFresh) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onOpen!(stock),
                    child: const Text('View Inst. Opportunity'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _offerLine(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) => Row(
    children: [
      Icon(icon, size: 18, color: valueColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: valueColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ],
  );
}
