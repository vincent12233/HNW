import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/portfolio_position.dart';
import '../../models/stock_quote.dart';
import '../../utils/number_formatters.dart';
import '../stock_logo.dart';

class HoldingsTab extends StatefulWidget {
  const HoldingsTab({
    super.key,
    required this.positions,
    required this.stocks,
    required this.onStockTap,
  });

  final Map<String, PortfolioPosition> positions;
  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  @override
  State<HoldingsTab> createState() => _HoldingsTabState();
}

class _HoldingsTabState extends State<HoldingsTab> {
  String selectedCategory = 'ALL';

  StockQuote? _findStock(String symbol) {
    for (final stock in widget.stocks) {
      if (stock.symbol == symbol) {
        return stock;
      }
    }

    return null;
  }

  String _positionCategory(PortfolioPosition position, StockQuote? stock) {
    final text = [
      position.symbol,
      position.name,
      position.category,
      stock?.category ?? '',
      stock?.name ?? '',
    ].join(' ').toUpperCase();

    if (text.contains('IPO')) {
      return 'IPO';
    }

    if (text.contains('OTC') || text.contains('BLOCK')) {
      return 'OTC';
    }

    return 'INSTITUTIONAL';
  }

  @override
  Widget build(BuildContext context) {
    final allPositions = widget.positions.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    final positionList = allPositions.where((position) {
      if (selectedCategory == 'ALL') {
        return true;
      }

      return _positionCategory(position, _findStock(position.symbol)) ==
          selectedCategory;
    }).toList();

    if (allPositions.isEmpty) {
      return _emptyState(
        'No holdings',
        'Your holdings will appear here after settled positions are added.',
      );
    }

    return Column(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _categoryChip('ALL', 'All'),
              _categoryChip('INSTITUTIONAL', 'Inst.'),
              _categoryChip('IPO', 'IPO'),
              _categoryChip('OTC', 'OTC'),
            ],
          ),
        ),
        Expanded(
          child: positionList.isEmpty
              ? _emptyState(
                  'No ${_categoryLabel(selectedCategory)} holdings',
                  'Positions in this category will appear here after settlement.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: positionList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final position = positionList[index];
                    final stock = _findStock(position.symbol);

                    final currentPrice = stock?.price ?? position.averageCost;
                    final marketValue = position.marketValue(currentPrice);
                    final profitLoss = position.unrealizedProfitLoss(
                      currentPrice,
                    );
                    final returnPercent = position.returnPercent(currentPrice);
                    final category = _positionCategory(position, stock);

                    final profitColor = profitLoss > 0
                        ? AppConfig.gainColor
                        : profitLoss < 0
                        ? AppConfig.lossColor
                        : AppConfig.neutralColor;

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: stock == null
                            ? null
                            : () {
                                widget.onStockTap(stock);
                              },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  StockLogo(
                                    symbol: position.symbol,
                                    logoUrl: position.logoUrl ?? stock?.logoUrl,
                                    size: 42,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          position.symbol,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          position.name.isEmpty
                                              ? '${position.quantity} shares'
                                              : position.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatPrice(marketValue),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${profitLoss > 0
                                            ? '+'
                                            : profitLoss < 0
                                            ? '-'
                                            : ''}'
                                        '${formatPrice(profitLoss.abs())}',
                                        style: TextStyle(
                                          color: profitColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _valueItem(
                                      'Qty',
                                      '${position.quantity}',
                                    ),
                                  ),
                                  Expanded(
                                    child: _valueItem(
                                      'Avg. Price',
                                      formatPrice(position.averageCost),
                                    ),
                                  ),
                                  Expanded(
                                    child: _valueItem(
                                      _categoryLabel(category),
                                      '${returnPercent > 0 ? '+' : ''}'
                                          '${returnPercent.toStringAsFixed(2)}%',
                                      valueColor: profitColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            selectedCategory = value;
          });
        },
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.black38,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'IPO':
        return 'IPO';
      case 'OTC':
        return 'OTC';
      case 'INSTITUTIONAL':
        return 'Inst.';
      default:
        return 'selected';
    }
  }

  Widget _valueItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
