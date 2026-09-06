import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../services/market_data_service.dart';
import '../services/market_socket_service.dart';
import '../services/watchlist_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_logo.dart';
import '../widgets/stock_list_tile.dart';
import 'stock_search_page.dart';

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
    required this.indexQuotes,
    required this.notificationCount,
    required this.onNotifications,
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
  final Map<String, (double, double)> indexQuotes;
  final int notificationCount;
  final VoidCallback onNotifications;
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
  int selectedMoverFilter = 0;
  String query = '';
  Timer? _searchDebounce;
  List<StockQuote> _remoteSearchResults = <StockQuote>[];
  List<StockQuote> _watchlistStocks = <StockQuote>[];
  Set<String> _watchlistSymbols = <String>{};
  bool _searchLoading = false;
  bool _searchHasMore = false;
  bool _watchlistLoading = true;
  final Map<String, List<double>> _indexHistory = <String, List<double>>{};
  final Map<String, List<double>> _stockHistory = <String, List<double>>{};
  int _searchPage = 1;
  int _searchGeneration = 0;

  final tabs = const [
    'Indices',
    'Stocks',
    'Sectors',
    'F&O',
    'ETFs',
    'Commodities',
    'Currency',
  ];

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
    unawaited(_loadIndexHistory());
    unawaited(_loadFeaturedStockHistory());
  }

  Future<void> _loadFeaturedStockHistory() async {
    final featured = _stocksInOrder(const [
      'HDFCBANK',
      'RELIANCE',
      'TCS',
      'ICICIBANK',
      'INFY',
    ]);
    final results = await Future.wait(
      featured.map((stock) async {
        try {
          final history = await _marketDataService.fetchHistory(
            symbol: stock.symbol,
            exchange: stock.exchange,
            range: '1D',
          );
          return (
            stock.symbol,
            history.data.map((point) => point.close).toList(),
          );
        } catch (_) {
          return (stock.symbol, <double>[]);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result.$2.length >= 2) _stockHistory[result.$1] = result.$2;
      }
    });
  }

  Future<void> _loadIndexHistory() async {
    const instruments = <(String, String, String)>[
      ('NIFTY 50', 'NIFTY50', 'NSE'),
      ('SENSEX', 'SENSEX', 'BSE'),
      ('BANK NIFTY', 'BANKNIFTY', 'NSE'),
      ('INDIA VIX', 'INDIAVIX', 'NSE'),
      ('DOW JONES', 'DJI', 'NYSE'),
      ('NASDAQ', 'IXIC', 'NASDAQ'),
      ('S&P 500', 'GSPC', 'NYSE'),
      ('FTSE 100', 'FTSE', 'LSE'),
    ];
    final results = await Future.wait(
      instruments.map((instrument) async {
        try {
          final history = await _marketDataService.fetchHistory(
            symbol: instrument.$2,
            exchange: instrument.$3,
            range: '1D',
          );
          return (
            instrument.$1,
            history.data.map((point) => point.close).toList(),
          );
        } catch (_) {
          return (instrument.$1, <double>[]);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result.$2.length >= 2) _indexHistory[result.$1] = result.$2;
      }
    });
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
    await _loadIndexHistory();
    await _loadFeaturedStockHistory();
    if (query.trim().isNotEmpty) {
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
    if (value.trim().isEmpty) return;
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
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Markets',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StockSearchPage(
                          initialStocks: widget.stocks,
                          onSelected: widget.onStockTap,
                          onWatchlistChanged: () => unawaited(_loadWatchlist()),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded, size: 28),
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: widget.onNotifications,
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 28,
                        ),
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          right: 6,
                          top: 4,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 17,
                              minHeight: 17,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF233C),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              widget.notificationCount > 9
                                  ? '9+'
                                  : widget.notificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
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
                      if (query.trim().isNotEmpty) {
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
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            const ['F&O', 'FUTURE', 'OPTION', 'DERIVATIVE'],
            emptyTitle: 'F&O instruments unavailable',
            emptySubtitle:
                'Derivative contracts will appear when enabled by the market catalog.',
          ),
        );
      case 4:
        return RefreshIndicator(onRefresh: _refreshAll, child: _etfList());
      case 5:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            const ['COMMODITY', 'MCX', 'METAL', 'ENERGY'],
            emptyTitle: 'Commodity instruments unavailable',
            emptySubtitle:
                'Commodity quotes will appear when enabled by the market catalog.',
          ),
        );
      case 6:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            const ['CURRENCY', 'FOREX', 'FX'],
            emptyTitle: 'Currency instruments unavailable',
            emptySubtitle:
                'Currency quotes will appear when enabled by the market catalog.',
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _indicesContent() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 22.0;
    final vix = _indexQuote(const ['INDIAVIX', 'INDIA VIX', 'VIX']);
    final dow = _indexQuote(const ['DJI', 'DOWJONES', 'DOW JONES']);
    final nasdaq = _indexQuote(const ['IXIC', 'NASDAQ']);
    final sp500 = _indexQuote(const ['GSPC', 'SP500', 'S&P500', 'S&P 500']);
    final ftse = _indexQuote(const ['FTSE', 'FTSE100', 'FTSE 100']);
    final indices = [
      ('NIFTY 50', widget.nifty50Price, widget.nifty50Change),
      ('SENSEX', widget.sensexPrice, widget.sensexChange),
      ('BANK NIFTY', widget.bankNiftyPrice, widget.bankNiftyChange),
      ('INDIA VIX', vix?.$1 ?? 0, vix?.$2 ?? 0),
    ];
    final globalIndices = [
      ('DOW JONES', dow?.$1 ?? 0, dow?.$2 ?? 0),
      ('NASDAQ', nasdaq?.$1 ?? 0, nasdaq?.$2 ?? 0),
      ('S&P 500', sp500?.$1 ?? 0, sp500?.$2 ?? 0),
      ('FTSE 100', ftse?.$1 ?? 0, ftse?.$2 ?? 0),
    ];
    final gainers = widget.stocks.where((stock) => stock.change > 0).toList()
      ..sort((a, b) => b.change.compareTo(a.change));
    final losers = widget.stocks.where((stock) => stock.change < 0).toList()
      ..sort((a, b) => a.change.compareTo(b.change));
    final unchanged = widget.stocks.where((stock) => stock.change == 0).length;
    final mostActive = [...widget.stocks]
      ..sort((a, b) => b.volume.compareTo(a.volume));
    final moverRows = switch (selectedMoverFilter) {
      0 => mostActive.take(5).toList(),
      1 => gainers.take(5).toList(),
      2 => losers.take(5).toList(),
      _ => <StockQuote>[],
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      children: [
        _marketSectionHeading('Indian Indices'),
        const SizedBox(height: 12),
        _indexGrid(indices),
        const SizedBox(height: 24),
        _marketSectionHeading('Global Indices'),
        const SizedBox(height: 12),
        _indexGrid(globalIndices),
        const SizedBox(height: 24),
        _marketSectionHeading('Market Movers'),
        const SizedBox(height: 10),
        _moverFilters(),
        const SizedBox(height: 8),
        _moverTable(moverRows),
        const SizedBox(height: 22),
        _marketSectionHeading('Market Breadth', showViewAll: false),
        const SizedBox(height: 12),
        _marketBreadth(gainers.length, losers.length, unchanged),
        const SizedBox(height: 18),
        _marketBanner(),
      ],
    );
  }

  (double, double)? _indexQuote(List<String> symbols) {
    for (final symbol in symbols) {
      final quote = widget.indexQuotes[symbol];
      if (quote != null) return quote;
    }
    return null;
  }

  List<StockQuote> _stocksInOrder(List<String> symbols) {
    final ordered = <StockQuote>[];
    for (final symbol in symbols) {
      for (final stock in widget.stocks) {
        if (stock.symbol == symbol) {
          ordered.add(stock);
          break;
        }
      }
    }
    return ordered;
  }

  Widget _marketSectionHeading(String title, {bool showViewAll = true}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      if (showViewAll)
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => selectedTab = 1),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 5),
            child: Text(
              'View All',
              style: TextStyle(
                color: AppConfig.primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _indexGrid(List<(String, double, double)> values) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 320 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.15
          ? 4
          : 2;
      final gap = 8.0;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: values
            .map((item) => SizedBox(width: width, child: _indexCard(item)))
            .toList(),
      );
    },
  );

  Widget _indexCard((String, double, double) item) {
    final available = item.$2 > 0;
    final positive = item.$3 >= 0;
    final color = !available
        ? AppConfig.neutralColor
        : positive
        ? AppConfig.gainColor
        : AppConfig.lossColor;
    final history = _indexHistory[item.$1] ?? const <double>[];
    return Container(
      height: 110,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (available)
                Icon(
                  positive
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: color,
                ),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.$2 > 0 ? item.$2.toStringAsFixed(2) : '--',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            available
                ? '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%'
                : 'Unavailable',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (available && history.length >= 2)
            SizedBox(
              height: 25,
              width: double.infinity,
              child: CustomPaint(
                painter: _IndexSparklinePainter(color, history),
              ),
            )
          else
            const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _moverFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children:
          [
                'Most Active',
                'Top Gainers',
                'Top Losers',
                '52 Week High',
                '52 Week Low',
              ]
              .asMap()
              .entries
              .map(
                (entry) => InkWell(
                  borderRadius: BorderRadius.circular(7),
                  onTap: () => setState(() => selectedMoverFilter = entry.key),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == selectedMoverFilter
                          ? const Color(0xFFEAF3FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppConfig.borderColor),
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 11,
                        color: entry.key == selectedMoverFilter
                            ? AppConfig.primaryColor
                            : const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    ),
  );

  Widget _moverTable(List<StockQuote> rows) {
    if (rows.isEmpty) {
      final unavailable = selectedMoverFilter >= 3;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.query_stats_rounded, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unavailable
                      ? '52-week statistics are not provided by the current market feed.'
                      : 'No instruments match this market filter.',
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 7),
            child: Row(
              children: [
                SizedBox(width: 39),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Name',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 47),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Price',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '% Change',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 55,
                  child: Text(
                    'Volume',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((stock) {
            final positive = stock.change >= 0;
            return InkWell(
              onTap: () => widget.onStockTap(stock),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    StockLogo(
                      symbol: stock.symbol,
                      logoUrl: stock.logoUrl,
                      size: 30,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayStockName(stock),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            stock.exchange,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      height: 22,
                      child: (_stockHistory[stock.symbol]?.length ?? 0) >= 2
                          ? CustomPaint(
                              painter: _IndexSparklinePainter(
                                positive
                                    ? AppConfig.gainColor
                                    : AppConfig.lossColor,
                                _stockHistory[stock.symbol]!,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      flex: 2,
                      child: Text(
                        stock.price.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          color: positive
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    SizedBox(
                      width: 48,
                      child: Text(
                        formatVolume(stock.volume),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _displayStockName(StockQuote stock) {
    const names = {
      'HDFCBANK': 'HDFC Bank',
      'RELIANCE': 'Reliance Industries',
      'TCS': 'Tata Consultancy',
      'ICICIBANK': 'ICICI Bank',
      'INFY': 'Infosys',
    };
    return names[stock.symbol] ?? stock.name;
  }

  Widget _marketBreadth(int advances, int declines, int unchanged) {
    final total = advances + declines + unchanged;
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Market breadth unavailable',
            style: TextStyle(color: AppConfig.textSecondaryColor),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConfig.borderColor),
      ),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Loaded instruments',
              style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 5,
            children: [
              Text(
                'Advances  $advances',
                style: const TextStyle(
                  color: AppConfig.gainColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Declines  $declines',
                style: const TextStyle(
                  color: AppConfig.lossColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Unchanged  $unchanged',
                style: const TextStyle(
                  color: AppConfig.neutralColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                if (advances > 0)
                  Expanded(
                    flex: advances,
                    child: Container(height: 8, color: AppConfig.gainColor),
                  ),
                if (declines > 0)
                  Expanded(
                    flex: declines,
                    child: Container(height: 8, color: AppConfig.lossColor),
                  ),
                if (unchanged > 0)
                  Expanded(
                    flex: unchanged,
                    child: Container(height: 8, color: const Color(0xFF98A2B3)),
                  ),
              ],
            ),
          ),
          Text(
            '${(advances / total * 100).toStringAsFixed(0)}% advancing',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _marketBanner() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFEEF5FF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Track live markets & place orders on the go',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Live prices, company logos and secure execution',
                style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        SizedBox(width: 12),
        Icon(
          Icons.candlestick_chart_rounded,
          color: AppConfig.gainColor,
          size: 50,
        ),
      ],
    ),
  );

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
    if (_searchLoading && query.trim().isNotEmpty && stocks.isEmpty) {
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
    final etfs = _filteredStocks.where((stock) {
      final category = stock.category?.toUpperCase() ?? '';
      return category.contains('ETF') || stock.symbol.endsWith('BEES');
    }).toList();
    return _stockList(
      etfs,
      emptyTitle: 'ETF data unavailable',
      emptySubtitle:
          'ETF quotes will appear when enabled by the market catalog.',
      allowPagination: query.trim().isNotEmpty,
    );
  }

  Widget _categoryList(
    List<String> keywords, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    final instruments = _filteredStocks.where((stock) {
      final category = stock.category?.trim().toUpperCase() ?? '';
      return keywords.any(category.contains);
    }).toList();
    return _stockList(
      instruments,
      emptyTitle: emptyTitle,
      emptySubtitle: emptySubtitle,
      allowPagination: query.trim().isNotEmpty,
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

class _IndexSparklinePainter extends CustomPainter {
  const _IndexSparklinePainter(this.color, this.values);
  final Color color;
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minimum = values.reduce((left, right) => left < right ? left : right);
    final maximum = values.reduce((left, right) => left > right ? left : right);
    final spread = maximum - minimum;
    final points = values
        .map(
          (value) =>
              spread <= 0 ? .5 : .88 - ((value - minimum) / spread) * .76,
        )
        .toList(growable: false);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * points[i];
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _IndexSparklinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
