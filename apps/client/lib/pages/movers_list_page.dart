import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../models/stock_quote.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/market_status_card.dart';
import '../widgets/stock_list_tile.dart';

class MoversListPage extends StatefulWidget {
  const MoversListPage({
    super.key,
    required this.gainers,
    required this.losers,
    required this.mostActive,
    required this.yearHigh,
    required this.yearLow,
    required this.onStockTap,
    this.initialFilter = 0,
    this.yearRangesLoading = false,
    this.onNeedYearRanges,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
    this.onRefresh,
  });

  final List<StockQuote> gainers;
  final List<StockQuote> losers;
  final List<StockQuote> mostActive;
  final List<StockQuote> yearHigh;
  final List<StockQuote> yearLow;
  final ValueChanged<StockQuote> onStockTap;
  final int initialFilter;
  final bool yearRangesLoading;
  final VoidCallback? onNeedYearRanges;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;
  final Future<void> Function()? onRefresh;

  @override
  State<MoversListPage> createState() => _MoversListPageState();
}

class _MoversListPageState extends State<MoversListPage> {
  static const _filters = [
    'Most Active',
    'Top Gainers',
    'Top Losers',
    '52 Week High',
    '52 Week Low',
  ];

  late int _filter = widget.initialFilter.clamp(0, _filters.length - 1);

  @override
  void initState() {
    super.initState();
    if (_filter >= 3) widget.onNeedYearRanges?.call();
  }

  List<StockQuote> get _rows {
    return switch (_filter) {
      0 => widget.mostActive,
      1 => widget.gainers,
      2 => widget.losers,
      3 => widget.yearHigh,
      4 => widget.yearLow,
      _ => const <StockQuote>[],
    };
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return AppPageScaffold(
      appBar: AppBar(title: const AppText('Market Movers')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: MarketStatusCard(
                  isOpen: widget.marketOpen,
                  hours: widget.marketHours,
                  quotesConnected: widget.quotesConnected,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var index = 0; index < _filters.length; index++)
                      Semantics(
                        button: true,
                        selected: _filter == index,
                        child: FilterChip(
                          label: AppText(_filters[index]),
                          selected: _filter == index,
                          onSelected: (_) {
                            setState(() => _filter = index);
                            if (index >= 3) widget.onNeedYearRanges?.call();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AppFadeIn(
                  switchKey: _filter,
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh ?? () async {},
                    child: rows.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: AppSpacing.page,
                            children: [
                              AppEmptyState(
                                title: widget.yearRangesLoading && _filter >= 3
                                    ? 'Loading one-year market history...'
                                    : 'No instruments match this market filter.',
                                message:
                                    widget.yearRangesLoading && _filter >= 3
                                    ? 'One-year highs and lows appear after verified history loads.'
                                    : 'Quotes will appear when the market catalog provides them.',
                                icon: Icons.query_stats_rounded,
                              ),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: rows.length,
                            itemBuilder: (context, index) {
                              final stock = rows[index];
                              return StockListTile(
                                stock: stock,
                                onTap: () => widget.onStockTap(stock),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
