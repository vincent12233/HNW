import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../services/market_data_service.dart';
import '../services/watchlist_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_list_tile.dart';

class MarketsPage extends StatefulWidget {
  const MarketsPage({
    super.key,
    required this.stocks,
    required this.onStockTap,
  });

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onStockTap;

  @override
  State<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends State<MarketsPage> {
  final MarketDataService _marketDataService = MarketDataService();
  final WatchlistService _watchlistService = WatchlistService();
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

  final tabs = const [
    'Stocks',
    'Watchlist',
    'Gainers',
    'Losers',
    'Sectors',
    'ETF',
  ];

  List<StockQuote> get _filteredStocks {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return widget.stocks;
    return _remoteSearchResults;
  }

  List<StockQuote> get _filteredWatchlistStocks {
    final bySymbol = <String, StockQuote>{};
    for (final stock in _watchlistStocks) {
      if (_watchlistSymbols.contains(stock.symbol)) {
        bySymbol[stock.symbol] = stock;
      }
    }
    for (final stock in widget.stocks) {
      if (_watchlistSymbols.contains(stock.symbol)) {
        bySymbol[stock.symbol] = stock;
      }
    }

    final normalized = query.trim().toLowerCase();
    final stocks = bySymbol.values.where((stock) {
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
    _loadWatchlist();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadWatchlist() async {
    if (mounted) {
      setState(() => _watchlistLoading = true);
    }

    try {
      final symbols = await _watchlistService.fetchSymbols();
      var stocks = <StockQuote>[];
      if (symbols.isNotEmpty) {
        final bootstrap = await _marketDataService.fetchHomeBootstrap(
          symbols: symbols,
          limit: 10,
        );
        stocks = bootstrap
            .where((stock) => symbols.contains(stock.symbol))
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _watchlistSymbols = symbols;
        _watchlistStocks = stocks;
        _watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _watchlistLoading = false);
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
    if (value.trim().isEmpty || selectedTab == 1) return;
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
          final existing = _remoteSearchResults.map((item) => item.symbol).toSet();
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
                  SizedBox(
                    width: 210,
                    child: SearchBar(
                      hintText: 'Search',
                      leading: const Icon(Icons.search, size: 20),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = selectedTab == index;

                  return ChoiceChip(
                    label: Text(tabs[index]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selectedTab = index;
                      });
                      if (index == 1) {
                        _loadWatchlist();
                      } else if (query.trim().isNotEmpty) {
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 300),
                          () => _searchStocks(reset: true),
                        );
                      }
                    },
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
        return _stockList(_filteredStocks, emptyTitle: 'No stocks found');

      case 1:
        if (_watchlistLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: _loadWatchlist,
          child: _stockList(
            _filteredWatchlistStocks,
            emptyTitle: 'Your watchlist is empty',
            emptySubtitle: 'Open a stock and tap the star to add it here.',
            allowPagination: false,
          ),
        );

      case 2:
        final gainers =
            _filteredStocks.where((stock) => stock.change > 0).toList()
              ..sort((a, b) => b.change.compareTo(a.change));

        return _stockList(gainers, emptyTitle: 'No gainers right now');

      case 3:
        final losers =
            _filteredStocks.where((stock) => stock.change < 0).toList()
              ..sort((a, b) => a.change.compareTo(b.change));

        return _stockList(losers, emptyTitle: 'No losers right now');

      case 4:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectorPerformance(stocks: widget.stocks),
            const SizedBox(height: 18),
            _sectorBreakdown(),
          ],
        );

      case 5:
        return _etfList();

      default:
        return const SizedBox.shrink();
    }
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
        selectedTab != 1) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stocks.isEmpty) {
      return _emptyState(Icons.star_border, emptyTitle, emptySubtitle);
    }

    final showMore = allowPagination &&
        query.trim().isNotEmpty &&
        _searchHasMore;
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
                onPressed: _searchLoading ? null : () => _searchStocks(reset: false),
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
    final rows = [
      ('Banking', 'HDFCBANK, ICICIBANK', Icons.account_balance_outlined),
      ('Information Technology', 'TCS, INFY', Icons.memory_outlined),
      ('Energy', 'RELIANCE', Icons.bolt_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sector Constituents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...rows.map((row) {
          return Card(
            child: ListTile(
              leading: Icon(row.$3, color: AppConfig.primaryColor),
              title: Text(row.$1),
              subtitle: Text(row.$2),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        }),
      ],
    );
  }

  Widget _etfList() {
    final etfs = [
      ('NIFTYBEES', 'Nippon India ETF Nifty 50', 282.45, 0.42),
      ('BANKBEES', 'Nippon India ETF Bank BeES', 532.10, -0.18),
      ('JUNIORBEES', 'Nippon India ETF Junior BeES', 745.35, 0.27),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: etfs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final etf = etfs[index];
        final positive = etf.$4 >= 0;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.pie_chart_outline)),
            title: Text(etf.$1),
            subtitle: Text(etf.$2),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(etf.$3),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${positive ? '+' : ''}${etf.$4.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: positive ? AppConfig.gainColor : AppConfig.lossColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
