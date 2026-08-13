import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../services/market_data_service.dart';
import '../services/market_socket_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_list_tile.dart';

class MarketsPage extends StatefulWidget {
  const MarketsPage({
    super.key,
    required this.stocks,
    required this.nifty50Price,
    required this.nifty50Change,
    required this.sensexPrice,
    required this.sensexChange,
    required this.bankNiftyPrice,
    required this.bankNiftyChange,
    required this.onStockTap,
    required this.onRefresh,
  });

  final List<StockQuote> stocks;
  final double nifty50Price;
  final double nifty50Change;
  final double sensexPrice;
  final double sensexChange;
  final double bankNiftyPrice;
  final double bankNiftyChange;
  final ValueChanged<StockQuote> onStockTap;
  final Future<void> Function() onRefresh;

  @override
  State<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends State<MarketsPage> {
  final MarketDataService _marketDataService = MarketDataService();
  final WatchlistService _watchlistService = WatchlistService();
  final MarketSocketService _marketSocket = MarketSocketService();
  int selectedTab = 0;
  String query = '';
  Timer? _searchDebounce;
  List<StockQuote> _remoteSearchResults = <StockQuote>[];
  List<StockQuote> _watchlistStocks = <StockQuote>[];
  Set<String> _watchlistSymbols = <String>{};
  bool _searchLoading = false;
  bool _searchHasMore = false;
  bool _watchlistLoading = true;
  int _searchPage = 1;
  int _searchGeneration = 0;

  final tabs = const ['Indices', 'Stocks', 'Sectors', 'Watchlist'];

  List<StockQuote> get _filteredStocks {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return widget.stocks;
    return _remoteSearchResults;
  }

  List<StockQuote> get _filteredWatchlistStocks {
    final byInstrument = <String, StockQuote>{};
    for (final stock in _watchlistStocks) {
      final key = WatchlistService.key(stock.exchange, stock.symbol);
      if (_watchlistSymbols.contains(key)) {
        byInstrument[key] = stock;
      }
    }
    for (final stock in widget.stocks) {
      final key = WatchlistService.key(stock.exchange, stock.symbol);
      if (_watchlistSymbols.contains(key)) {
        byInstrument[key] = stock;
      }
    }

    final normalized = query.trim().toLowerCase();
    final stocks = byInstrument.values.where((stock) {
      if (normalized.isEmpty) return true;
      return stock.symbol.toLowerCase().contains(normalized) ||
          stock.name.toLowerCase().contains(normalized);
    }).toList();

    stocks.sort((left, right) => left.symbol.compareTo(right.symbol));
    return stocks;
  }

  @override
  void initState() {
    super.initState();
    _marketSocket.addQuoteListener(_handleRealtimeQuote);
    _loadWatchlist();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _marketSocket.removeQuoteListener(_handleRealtimeQuote);
    super.dispose();
  }

  void _handleRealtimeQuote(Map<String, dynamic> data) {
    if (!mounted) return;
    var changed = false;
    changed = _updateRealtimeList(_remoteSearchResults, data) || changed;
    changed = _updateRealtimeList(_watchlistStocks, data) || changed;
    if (changed) setState(() {});
  }

  bool _updateRealtimeList(List<StockQuote> stocks, Map<String, dynamic> data) {
    for (var index = 0; index < stocks.length; index++) {
      final updated = StockQuote.applyRealtime(stocks[index], data);
      if (updated == null) continue;
      stocks[index] = updated;
      return true;
    }
    return false;
  }

  Future<void> _loadWatchlist() async {
    if (mounted) {
      setState(() => _watchlistLoading = true);
    }

    try {
      final instrumentKeys = await _watchlistService.fetchSymbols();
      var stocks = <StockQuote>[];
      if (instrumentKeys.isNotEmpty) {
        final symbols = instrumentKeys
            .map((key) => key.split(':').last)
            .toSet();
        final bootstrap = await _marketDataService.fetchHomeBootstrap(
          symbols: symbols,
          limit: 10,
          preserveExchanges: true,
        );
        stocks = bootstrap
            .where(
              (stock) => instrumentKeys.contains(
                WatchlistService.key(stock.exchange, stock.symbol),
              ),
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _watchlistSymbols = instrumentKeys;
        _watchlistStocks = stocks;
        _watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _watchlistLoading = false);
    }
  }

  Future<void> _refreshAll() async {
    await widget.onRefresh();
    await _loadWatchlist();
    if (query.trim().isNotEmpty && selectedTab != 3) {
      await _searchStocks(reset: true);
    }
  }

  void _onSearchChanged(String value) {
    _searchGeneration++;
    setState(() {
      query = value;
      if (value.trim().isEmpty) {
        _remoteSearchResults = <StockQuote>[];
        _searchHasMore = false;
        _searchLoading = false;
      }
    });

    _searchDebounce?.cancel();
    if (value.trim().isEmpty || selectedTab == 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchStocks(reset: true);
    });
  }

  Future<void> _searchStocks({required bool reset}) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || _searchLoading) return;

    final generation = reset ? ++_searchGeneration : _searchGeneration;
    final nextPage = reset ? 1 : _searchPage + 1;
    setState(() {
      _searchLoading = true;
    });

    try {
      final result = await _marketDataService.searchSnapshot(
        query: normalizedQuery,
        page: nextPage,
        pageSize: 50,
      );
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        if (reset) {
          _remoteSearchResults = result.data;
        } else {
          final existing = _remoteSearchResults
              .map((item) => item.symbol)
              .toSet();
          _remoteSearchResults.addAll(
            result.data.where((item) => !existing.contains(item.symbol)),
          );
        }
        _searchPage = result.page;
        _searchHasMore = result.hasMore;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      if (reset) {
        final normalized = normalizedQuery.toLowerCase();
        setState(() {
          _remoteSearchResults = widget.stocks.where((stock) {
            return stock.symbol.toLowerCase().contains(normalized) ||
                stock.name.toLowerCase().contains(normalized);
          }).toList();
          _searchHasMore = false;
        });
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() {
          _searchLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Markets',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => showSearch<StockQuote?>(
                      context: context,
                      delegate: _MarketSearchDelegate(
                        stocks: widget.stocks,
                        onSelected: widget.onStockTap,
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 28),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.notifications_none_rounded, size: 28),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = selectedTab == index;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedTab = index;
                      });
                      if (index == 3) {
                        _loadWatchlist();
                      } else if (query.trim().isNotEmpty) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () => _searchStocks(reset: true),
                        );
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? AppConfig.primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          color: selected
                              ? AppConfig.primaryColor
                              : const Color(0xFF475569),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _selectedContent()),
          ],
        ),
      ),
    );
  }

  Widget _selectedContent() {
    switch (selectedTab) {
      case 0:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _indicesContent(),
        );

      case 1:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _stockList(_filteredStocks, emptyTitle: 'No stocks found'),
        );

      case 2:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SectorPerformance(stocks: widget.stocks),
              const SizedBox(height: 18),
              _sectorBreakdown(),
            ],
          ),
        );

      case 3:
        if (_watchlistLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _stockList(
            _filteredWatchlistStocks,
            emptyTitle: 'Your watchlist is empty',
            emptySubtitle: 'Open a stock and tap the star to add it here.',
            allowPagination: false,
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _indicesContent() {
    final indices = [
      ('NIFTY 50', widget.nifty50Price, widget.nifty50Change),
      ('SENSEX', widget.sensexPrice, widget.sensexChange),
      ('BANK NIFTY', widget.bankNiftyPrice, widget.bankNiftyChange),
    ];
    final gainers = [...widget.stocks]
      ..sort((a, b) => b.change.compareTo(a.change));
    final losers = [...widget.stocks]
      ..sort((a, b) => a.change.compareTo(b.change));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: [
        const Text(
          'Indian Indices',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: indices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = indices[index];
              final positive = item.$3 >= 0;
              final color = positive
                  ? AppConfig.gainColor
                  : AppConfig.lossColor;
              return Container(
                width: 172,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConfig.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.$2 > 0 ? item.$2.toStringAsFixed(2) : '--',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Market Movers',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _moverColumn(
                'Top Gainers',
                gainers.take(5).toList(),
                true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _moverColumn('Top Losers', losers.take(5).toList(), false),
            ),
          ],
        ),
      ],
    );
  }

  Widget _moverColumn(String title, List<StockQuote> rows, bool positive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...rows.map(
            (stock) => InkWell(
              onTap: () => widget.onStockTap(stock),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stock.symbol,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: positive
                            ? AppConfig.gainColor
                            : AppConfig.lossColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockList(
    List<StockQuote> stocks, {
    required String emptyTitle,
    String emptySubtitle = 'Try a different search or market filter.',
    bool allowPagination = true,
  }) {
    if (_searchLoading &&
        query.trim().isNotEmpty &&
        stocks.isEmpty &&
        selectedTab != 3) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stocks.isEmpty) {
      return _emptyState(Icons.star_border, emptyTitle, emptySubtitle);
    }

    final showMore =
        allowPagination && query.trim().isNotEmpty && _searchHasMore;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length + (showMore ? 1 : 0),
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == stocks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton(
                onPressed: _searchLoading
                    ? null
                    : () => _searchStocks(reset: false),
                child: _searchLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Load more'),
              ),
            ),
          );
        }

        final stock = stocks[index];
        return StockListTile(
          stock: stock,
          onTap: () {
            widget.onStockTap(stock);
          },
        );
      },
    );
  }

  Widget _sectorBreakdown() {
    final groups = <String, List<StockQuote>>{};
    for (final stock in widget.stocks) {
      final category = stock.category?.trim();
      if (category == null || category.isEmpty) continue;
      groups.putIfAbsent(category, () => <StockQuote>[]).add(stock);
    }
    final rows = groups.entries.toList()
      ..sort((left, right) => right.value.length.compareTo(left.value.length));

    if (rows.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.category_outlined, color: Colors.blueGrey),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sector classifications are currently unavailable.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sector Constituents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...rows.take(12).map((row) {
          final symbols = row.value
              .map((stock) => stock.symbol)
              .take(4)
              .join(', ');
          return Card(
            child: ListTile(
              leading: const Icon(
                Icons.category_outlined,
                color: AppConfig.primaryColor,
              ),
              title: Text(row.key),
              subtitle: Text(symbols),
              trailing: Text('${row.value.length}'),
            ),
          );
        }),
      ],
    );
  }

  Widget _etfList() {
    final etfs = widget.stocks.where((stock) {
      final category = stock.category?.toUpperCase() ?? '';
      return category.contains('ETF') || stock.symbol.endsWith('BEES');
    }).toList();
    return _stockList(
      etfs,
      emptyTitle: 'ETF data unavailable',
      emptySubtitle:
          'ETF quotes will appear when enabled by the market catalog.',
      allowPagination: false,
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: Colors.blueGrey),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}

class _MarketSearchDelegate extends SearchDelegate<StockQuote?> {
  _MarketSearchDelegate({required this.stocks, required this.onSelected});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onSelected;

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  @override
  Widget buildResults(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final needle = query.trim().toLowerCase();
    final results = stocks.where(
      (stock) =>
          needle.isEmpty ||
          stock.symbol.toLowerCase().contains(needle) ||
          stock.name.toLowerCase().contains(needle),
    );
    return ListView(
      children: results
          .map(
            (stock) => StockListTile(
              stock: stock,
              onTap: () {
                close(context, stock);
                onSelected(stock);
              },
            ),
          )
          .toList(),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );
}
