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
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final position = positionList[index];
                    final stock = _findStock(
                      position.symbol,
                      position.exchange,
                    );

                    final currentPrice = stock?.price ?? position.averageCost;
                    final invested = position.quantity * position.averageCost;
                    final marketValue = position.marketValue(currentPrice);
                    final profitLoss = position.unrealizedProfitLoss(
                      currentPrice,
                    );
                    final returnPercent = position.returnPercent(currentPrice);
                    final category = _positionCategory(position, stock);
                    final dayChange = stock?.previousClose != null &&
                            stock!.previousClose! > 0
                        ? (currentPrice - stock.previousClose!) *
                            position.quantity
                        : null;
                    final dayChangePercent = stock?.change;

                    final profitColor = profitLoss > 0
                        ? AppConfig.gainColor
                        : profitLoss < 0
                        ? AppConfig.lossColor
                        : AppConfig.neutralColor;
                    final dayColor = (dayChange ?? 0) > 0
                        ? AppConfig.gainColor
                        : (dayChange ?? 0) < 0
                        ? AppConfig.lossColor
                        : AppConfig.neutralColor;

                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: stock == null
                            ? null
                            : () {
                                widget.onStockTap(stock);
                              },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8EDF5)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  StockLogo(
                                    symbol: position.symbol,
                                    logoUrl:
                                        position.logoUrl ?? stock?.logoUrl,
                                    size: 38,
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
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
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
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            _holdingTag(position.exchange),
                                            _holdingTag(
                                              _categoryLabel(category),
                                              accent: true,
                                            ),
                                            _holdingTag(
                                              '${position.quantity} qty',
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AppText(
                                        formatPrice(currentPrice),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (dayChangePercent != null) ...[
                                        const SizedBox(height: 3),
                                        AppText(
                                          '${dayChangePercent >= 0 ? '+' : ''}${dayChangePercent.toStringAsFixed(2)}%',
                                          style: TextStyle(
                                            color: dayColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _metricColumn(
                                        'Invested',
                                        formatPrice(invested),
                                      ),
                                    ),
                                    Expanded(
                                      child: _metricColumn(
                                        'Current',
                                        formatPrice(marketValue),
                                      ),
                                    ),
                                    Expanded(
                                      child: _metricColumn(
                                        'P&L',
                                        '${profitLoss >= 0 ? '+' : ''}${formatPrice(profitLoss.abs())}',
                                        valueColor: profitColor,
                                        subtitle:
                                            '${returnPercent >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (dayChange != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const AppText(
                                      'Day’s change',
                                      style: TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    AppText(
                                      '${dayChange >= 0 ? '+' : ''}${formatPrice(dayChange.abs())}',
                                      style: TextStyle(
                                        color: dayColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: AppText(
                                      'Avg ${formatPrice(position.averageCost)}',
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  AppText(
                                    'Avail ${position.availableQuantity}',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 11,
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

  Widget _metricColumn(
    String label,
    String value, {
    Color? valueColor,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        AppText(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          AppText(
            subtitle,
            style: TextStyle(
              color: valueColor ?? const Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
