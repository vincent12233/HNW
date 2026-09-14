import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/portfolio_position.dart';
import '../../models/stock_quote.dart';
import '../../services/app_content_service.dart';
import '../../utils/number_formatters.dart';
import '../../utils/product_category.dart';
import '../stock_logo.dart';
import '../responsive_empty_state.dart';

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

  StockQuote? _findStock(String symbol, String exchange) {
    for (final stock in widget.stocks) {
      if (stock.symbol == symbol && stock.exchange == exchange) {
        return stock;
      }
    }

    return null;
  }

  String _positionCategory(PortfolioPosition position, StockQuote? stock) {
    return portfolioCategory(position.category)?.toUpperCase() ?? 'EQUITY';
  }

  @override
  Widget build(BuildContext context) {
    final allPositions = widget.positions.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));
    final positionList = allPositions.where((position) {
      if (selectedCategory == 'ALL') {
        return true;
      }

      return _positionCategory(
            position,
            _findStock(position.symbol, position.exchange),
          ) ==
          selectedCategory;
    }).toList();

    if (allPositions.isEmpty) {
      final content = AppContentService.instance.current;
      return _emptyState(
        content.text(
          'trading',
          'holdings.empty_title',
          fallback: 'No holdings',
        ),
        content.text(
          'trading',
          'holdings.empty_subtitle',
          fallback:
              'Your holdings will appear here after settled positions are added.',
        ),
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
              _categoryChip('EQUITY', 'Equities'),
              _categoryChip('INSTITUTIONAL', 'Institutional'),
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
                    final stock = _findStock(
                      position.symbol,
                      position.exchange,
                    );

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
                                        AppText(
                                          position.symbol,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        AppText(
                                          position.name.isEmpty
                                              ? '${position.quantity} shares'
                                              : position.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _holdingTag(position.exchange),
                                            _holdingTag(
                                              _categoryLabel(category),
                                              accent: true,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        AppText(
                                          formatPrice(marketValue),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        AppText(
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
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _valueItem(
                                      'Quantity / Available',
                                      '${position.quantity} / ${position.availableQuantity}',
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
                                      'Returns',
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
        label: AppText(label),
        selected: selected,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppConfig.textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
        onSelected: (_) {
          setState(() {
            selectedCategory = value;
          });
        },
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return ResponsiveEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: title,
      subtitle: subtitle,
    );
  }

  String _categoryLabel(String value) {
    switch (value) {
      case 'IPO':
        return 'IPO';
      case 'OTC':
        return 'OTC';
      case 'INSTITUTIONAL':
        return 'Institutional';
      default:
        return 'Equity';
    }
  }

  Widget _holdingTag(String label, {bool accent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFEAF1FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(5),
      ),
      child: AppText(
        label,
        style: TextStyle(
          color: accent ? AppConfig.primaryColor : const Color(0xFF64748B),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _valueItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
