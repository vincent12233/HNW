import '../../l10n/app_language.dart';
import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../models/portfolio_position.dart';
import '../../models/stock_quote.dart';
import '../../services/app_content_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../utils/number_formatters.dart';
import '../../utils/product_category.dart';
import '../stock_logo.dart';
import '../app_page_scaffold.dart';
import '../holding_detail_sheet.dart';

class HoldingsTab extends StatefulWidget {
  const HoldingsTab({
    super.key,
    required this.positions,
    required this.stocks,
    required this.onSell,
  });

  final Map<String, PortfolioPosition> positions;
  final List<StockQuote> stocks;
  final void Function(StockQuote stock, {required bool isBuy}) onSell;

  @override
  State<HoldingsTab> createState() => _HoldingsTabState();
}

class _HoldingsTabState extends State<HoldingsTab> {
  String selectedCategory = 'ALL';
  String selectedView = 'HOLDINGS';

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _viewChip('HOLDINGS', 'Holdings'),
              _viewChip('POSITIONS', 'Positions'),
            ],
          ),
        ),
        if (allPositions.isEmpty)
          Expanded(
            child: AppStatusSwitch(
              switchKey: selectedView,
              child: _emptyState(
                selectedView == 'POSITIONS' ? 'No positions' : 'No holdings',
                selectedView == 'POSITIONS'
                    ? 'Open positions will appear here after the account has live exposure.'
                    : AppContentService.instance.current.text(
                        'trading',
                        'holdings.empty_subtitle',
                        fallback:
                            'Your holdings will appear here after settled positions are added.',
                      ),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
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
                : AppStatusSwitch(
                    switchKey:
                        '$selectedView|$selectedCategory|${positionList.length}',
                    child: ListView.separated(
                      key: ValueKey('$selectedView|$selectedCategory'),
                      padding: const EdgeInsets.all(16),
                      itemCount: positionList.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final position = positionList[index];
                        final stock = _findStock(
                          position.symbol,
                          position.exchange,
                        );

                        final usableQuote = holdingQuoteUsable(stock);
                        final delayed = stock != null && !stock.quoteFresh;
                        final currentPrice = usableQuote ? stock!.price : null;
                        final invested =
                            position.quantity * position.averageCost;
                        final marketValue = currentPrice == null
                            ? null
                            : position.marketValue(currentPrice);
                        final profitLoss = currentPrice == null
                            ? null
                            : position.unrealizedProfitLoss(currentPrice);
                        final returnPercent = currentPrice == null
                            ? null
                            : position.returnPercent(currentPrice);
                        final frozen = holdingFrozenQuantity(position);
                        final category = _positionCategory(position, stock);
                        final dayChange =
                            currentPrice != null &&
                                stock?.previousClose != null &&
                                stock!.previousClose! > 0
                            ? (currentPrice - stock.previousClose!) *
                                  position.quantity
                            : null;
                        final dayChangePercent = usableQuote
                            ? stock?.change
                            : null;

                        final profitColor = (profitLoss ?? 0) > 0
                            ? AppConfig.gainColor
                            : (profitLoss ?? 0) < 0
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
                            onTap: () => showHoldingDetails(
                              context,
                              position: position,
                              quote: stock,
                              onSell: (quote) =>
                                  widget.onSell(quote, isBuy: false),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE8EDF5),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                                if (selectedView == 'POSITIONS')
                                                  _holdingTag(
                                                    frozen > 0
                                                        ? 'Frozen $frozen'
                                                        : 'Unfrozen',
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
                                              currentPrice == null
                                                  ? 'Unavailable'
                                                  : formatPrice(currentPrice),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                              ),
                                            ),
                                            if (delayed) ...[
                                              const SizedBox(height: 3),
                                              AppText(
                                                'Delayed quote',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: AppColors.warning,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                            if (dayChangePercent != null) ...[
                                              const SizedBox(height: 3),
                                              AppText(
                                                '${dayChangePercent >= 0 ? '+' : ''}${dayChangePercent.toStringAsFixed(2)}% · ${dayChangePercent > 0
                                                    ? 'Gain'
                                                    : dayChangePercent < 0
                                                    ? 'Loss'
                                                    : 'Unchanged'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.end,
                                                style: TextStyle(
                                                  color: dayColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final stacked =
                                            constraints.maxWidth < 300;
                                        final metrics = [
                                          _metricColumn(
                                            'Invested',
                                            formatPrice(invested),
                                          ),
                                          _metricColumn(
                                            'Current',
                                            marketValue == null
                                                ? 'Unavailable'
                                                : formatPrice(marketValue),
                                          ),
                                          _metricColumn(
                                            'Unrealized P&L',
                                            profitLoss == null
                                                ? 'Unavailable'
                                                : '${formatSignedPrice(profitLoss)} · ${profitLoss > 0
                                                      ? 'Gain'
                                                      : profitLoss < 0
                                                      ? 'Loss'
                                                      : 'Unchanged'}',
                                            valueColor: profitLoss == null
                                                ? AppColors.textSecondary
                                                : profitColor,
                                            subtitle: returnPercent == null
                                                ? null
                                                : '${returnPercent >= 0 ? '+' : ''}${returnPercent.toStringAsFixed(2)}%',
                                          ),
                                        ];
                                        if (stacked) {
                                          return Column(
                                            children: [
                                              for (
                                                var i = 0;
                                                i < metrics.length;
                                                i++
                                              ) ...[
                                                if (i > 0)
                                                  const SizedBox(height: 10),
                                                SizedBox(
                                                  width: double.infinity,
                                                  child: metrics[i],
                                                ),
                                              ],
                                            ],
                                          );
                                        }
                                        return Row(
                                          children: [
                                            for (final metric in metrics)
                                              Expanded(child: metric),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  if (dayChange != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: AppText(
                                            'Day’s change',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: AppText(
                                            '${formatSignedPrice(dayChange)} · ${dayChange > 0
                                                ? 'Gain'
                                                : dayChange < 0
                                                ? 'Loss'
                                                : 'Unchanged'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.end,
                                            style: TextStyle(
                                              color: dayColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                          selectedView == 'POSITIONS'
                                              ? 'Frozen $frozen · Avail ${position.availableQuantity}'
                                              : 'Avg ${formatPrice(position.averageCost)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: AppText(
                                          selectedView == 'POSITIONS'
                                              ? 'Avg ${formatPrice(position.averageCost)}'
                                              : 'Avail ${position.availableQuantity} · Frozen $frozen',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 11,
                                          ),
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
          ),
        ],
      ],
    );
  }

  Widget _viewChip(String value, String label) {
    final selected = selectedView == value;
    return ChoiceChip(
      key: ValueKey('holding-filter-$value'),
      label: AppText(label),
      selected: selected,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppConfig.textPrimaryColor,
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => setState(() => selectedView = value),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = selectedCategory == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        key: ValueKey('holding-category-$value'),
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
    return AppEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: title,
      message: subtitle,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: AppText(
            value,
            maxLines: 1,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          AppText(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
