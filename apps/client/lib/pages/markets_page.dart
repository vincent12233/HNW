import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../services/app_content_service.dart';
import '../services/featured_instruments_service.dart';
import '../services/market_data_service.dart';
import '../services/logo_market_page.dart';
import '../services/market_socket_service.dart';
import '../services/watchlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_logo.dart';
import '../widgets/stock_list_tile.dart';
import '../widgets/market_status_card.dart';
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
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
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
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;

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
  List<StockQuote> _remoteSearchResults = <StockQuote>[];
  List<StockQuote> _watchlistStocks = <StockQuote>[];
  bool _searchLoading = false;
  bool _searchFailed = false;
  bool _failedSearchWasReset = true;
  bool _searchHasMore = false;
  bool _watchlistLoading = true;
  bool _watchlistFailed = false;
  final Map<String, List<double>> _indexHistory = <String, List<double>>{};
  final Map<String, List<double>> _stockHistory = <String, List<double>>{};
  final List<StockQuote> _marketsFeatured = <StockQuote>[];
  final Map<String, (double, double)> _yearRanges =
      <String, (double, double)>{};
  bool _yearRangesLoading = false;
  int _searchPage = 1;
  int _searchGeneration = 0;

  static const _foKeywords = ['F&O', 'FUTURE', 'OPTION', 'DERIVATIVE'];
  static const _commodityKeywords = ['COMMODITY', 'MCX', 'METAL', 'ENERGY'];
  static const _currencyKeywords = ['CURRENCY', 'FOREX', 'FX'];

  /// Always-visible core tabs, then optional catalog tabs when instruments exist.
  List<(int contentIndex, String label)> get _visibleTabs {
    final tabs = <(int, String)>[
      (0, 'Watchlist'),
      (1, 'Indices'),
      (2, 'Stocks'),
      (3, 'Sectors'),
    ];
    if (_hasCategoryInstruments(_foKeywords)) {
      tabs.add((4, 'F&O'));
    }
    if (_hasEtfInstruments()) {
      tabs.add((5, 'ETFs'));
    }
    if (_hasCategoryInstruments(_commodityKeywords)) {
      tabs.add((6, 'Commodities'));
    }
    if (_hasCategoryInstruments(_currencyKeywords)) {
      tabs.add((7, 'Currency'));
    }
    return tabs;
  }

  bool _hasCategoryInstruments(List<String> keywords) {
    return _remoteSearchResults.any((stock) {
      final category = stock.category?.trim().toUpperCase() ?? '';
      return keywords.any(category.contains);
    });
  }

  bool _hasEtfInstruments() {
    return _remoteSearchResults.any((stock) {
      final category = stock.category?.toUpperCase() ?? '';
      return category.contains('ETF') || stock.symbol.endsWith('BEES');
    });
  }

  void _clampSelectedTab() {
    final visible = _visibleTabs;
    if (!visible.any((tab) => tab.$1 == selectedTab)) {
      selectedTab = visible.first.$1;
    }
  }

  List<StockQuote> get _filteredStocks {
    return _remoteSearchResults
        .where(
          (stock) =>
              stock.logoUrl?.trim().isNotEmpty == true &&
              !_failedLogoUrls.contains(stock.logoUrl),
        )
        .toList();
  }

  final Set<String> _failedLogoUrls = {};

  @override
  void initState() {
    super.initState();
    _marketSocket.addQuoteListener(_handleRealtimeQuote);
    _loadWatchlist();
    unawaited(_loadIndexHistory());
    unawaited(_loadFeaturedStockHistory());
    unawaited(_searchStocks(reset: true));
    unawaited(AppContentService.instance.load());
  }

  Future<void> _loadFeaturedStockHistory() async {
    final featured = await FeaturedInstrumentsService.instance
        .marketsFeatured();
    if (!mounted) return;
    setState(() {
      _marketsFeatured
        ..clear()
        ..addAll(featured);
    });
    if (featured.isEmpty) return;
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

  String _instrumentKey(StockQuote stock) =>
      '${stock.exchange}:${stock.symbol}';

  Future<void> _loadYearRanges({bool force = false}) async {
    if (_yearRangesLoading || (!force && _yearRanges.isNotEmpty)) return;
    if (mounted) setState(() => _yearRangesLoading = true);
    final candidates = widget.stocks.where((stock) => stock.price > 0).toList()
      ..sort((left, right) => right.volume.compareTo(left.volume));
    final results = await Future.wait(
      candidates.take(20).map((stock) async {
        try {
          final history = await _marketDataService.fetchHistory(
            symbol: stock.symbol,
            exchange: stock.exchange,
            range: '1Y',
          );
          final prices = history.data
              .map((point) => point.close)
              .where((price) => price > 0)
              .toList();
          if (prices.length < 2) return (_instrumentKey(stock), null);
          prices.sort();
          return (_instrumentKey(stock), (prices.first, prices.last));
        } catch (_) {
          return (_instrumentKey(stock), null);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      if (force) _yearRanges.clear();
      for (final result in results) {
        if (result.$2 != null) _yearRanges[result.$1] = result.$2!;
      }
      _yearRangesLoading = false;
    });
  }

  @override
  void dispose() {
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
      setState(() {
        _watchlistLoading = true;
      });
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
        _watchlistStocks = stocks;
        _watchlistLoading = false;
        _watchlistFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _watchlistLoading = false;
        _watchlistFailed = true;
      });
    }
  }

  Future<void> _refreshAll() async {
    _failedLogoUrls.clear();
    await widget.onRefresh();
    await _loadWatchlist();
    await _loadIndexHistory();
    await _loadFeaturedStockHistory();
    if (selectedMoverFilter >= 3) await _loadYearRanges(force: true);
    await _searchStocks(reset: true);
  }

  Future<void> _searchStocks({required bool reset}) async {
    final normalizedQuery = query.trim();
    if (_searchLoading) return;

    final generation = reset ? ++_searchGeneration : _searchGeneration;
    final nextPage = reset ? 1 : _searchPage + 1;
    setState(() {
      _searchLoading = true;
      _searchFailed = false;
    });

    try {
      final result = await loadLogoMarketPage(
        page: nextPage,
        fetch: (page) => _marketDataService.searchSnapshot(
          query: normalizedQuery,
          page: page,
          pageSize: 50,
        ),
        failedUrls: _failedLogoUrls,
        isCurrent: () => mounted && generation == _searchGeneration,
      );
      if (!mounted || generation != _searchGeneration) return;

      setState(() {
        if (reset) {
          _remoteSearchResults = result.data;
        } else {
          final existing = _remoteSearchResults
              .map((item) => '${item.exchange}:${item.symbol}')
              .toSet();
          _remoteSearchResults.addAll(
            result.data.where(
              (item) => !existing.contains('${item.exchange}:${item.symbol}'),
            ),
          );
        }
        _searchPage = result.page;
        _searchHasMore = result.hasMore;
        _clampSelectedTab();
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchFailed = true;
        _failedSearchWasReset = reset;
      });
      if (reset) {
        final normalized = normalizedQuery.toLowerCase();
        setState(() {
          _remoteSearchResults = widget.stocks.where((stock) {
            return stock.symbol.toLowerCase().contains(normalized) ||
                stock.name.toLowerCase().contains(normalized);
          }).toList();
          _searchHasMore = false;
          _clampSelectedTab();
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
    final visibleTabs = _visibleTabs;
    final effectiveTab = visibleTabs.any((tab) => tab.$1 == selectedTab)
        ? selectedTab
        : visibleTabs.first.$1;
    if (effectiveTab != selectedTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_visibleTabs.any((tab) => tab.$1 == selectedTab)) {
          setState(_clampSelectedTab);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + 2,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      'Markets',
                      style: AppTypography.headline.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: widget.onNotifications,
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textPrimary,
                          size: 22,
                        ),
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          right: 8,
                          top: 7,
                          child: Container(
                            width: 17,
                            height: 17,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.loss,
                              shape: BoxShape.circle,
                            ),
                            child: AppText(
                              widget.notificationCount > 9
                                  ? '9+'
                                  : widget.notificationCount.toString(),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textInverse,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md - 2,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StockSearchPage(
                        initialStocks: widget.stocks,
                        onSelected: widget.onStockTap,
                        onWatchlistChanged: () => unawaited(_loadWatchlist()),
                      ),
                    ),
                  ),
                  borderRadius: AppRadius.borderSm,
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppText(
                            'Search stocks…',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                scrollDirection: Axis.horizontal,
                itemCount: visibleTabs.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final tab = visibleTabs[index];
                  final contentIndex = tab.$1;
                  final selected = effectiveTab == contentIndex;

                  return Semantics(
                    button: true,
                    selected: selected,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selectedTab = contentIndex;
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: selected
                                  ? AppColors.brandPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: AppText(
                          tab.$2,
                          style: AppTypography.labelSmall.copyWith(
                            color: selected
                                ? AppColors.brandPrimary
                                : AppColors.textSecondary,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(child: _selectedContent(contentIndex: effectiveTab)),
          ],
        ),
      ),
    );
  }

  Widget _selectedContent({int? contentIndex}) {
    switch (contentIndex ?? selectedTab) {
      case 0:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _watchlistContent(),
        );

      case 1:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _indicesContent(),
        );

      case 2:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _stockList(
            _filteredStocks,
            emptyTitle: 'No instruments available',
            emptySubtitle:
                'Stock quotes will appear when enabled by the market catalog.',
          ),
        );

      case 3:
        final hasCategories = widget.stocks.any(
          (stock) => stock.category?.trim().isNotEmpty == true,
        );
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: hasCategories
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: AppSpacing.page,
                  children: [
                    SectorPerformance(stocks: widget.stocks),
                    const SizedBox(height: AppSpacing.lg + 2),
                    _sectorBreakdown(),
                  ],
                )
              : _emptyState(
                  Icons.category_outlined,
                  'No sector data',
                  'Sector classifications are currently unavailable for this market catalog.',
                ),
        );

      case 4:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _foKeywords,
            emptyTitle: 'F&O instruments unavailable',
            emptySubtitle:
                'Derivative contracts will appear when enabled by the market catalog.',
          ),
        );
      case 5:
        return RefreshIndicator(onRefresh: _refreshAll, child: _etfList());
      case 6:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _commodityKeywords,
            emptyTitle: 'Commodity instruments unavailable',
            emptySubtitle:
                'Commodity quotes will appear when enabled by the market catalog.',
          ),
        );
      case 7:
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: _categoryList(
            _currencyKeywords,
            emptyTitle: 'Currency instruments unavailable',
            emptySubtitle:
                'Currency quotes will appear when enabled by the market catalog.',
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _watchlistContent() {
    if (_watchlistLoading && _watchlistStocks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: const AppLoadingView(message: 'Loading watchlist…'),
            ),
          );
        },
      );
    }
    if (_watchlistFailed && _watchlistStocks.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child: AppErrorView(
                title: 'Unable to load watchlist',
                message: 'Watchlist data is unavailable. Please try again.',
                onRetry: () => unawaited(_loadWatchlist()),
              ),
            ),
          );
        },
      );
    }
    if (_watchlistStocks.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),
          Icon(
            Icons.star_border_rounded,
            size: 40,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppText(
            'Your watchlist is empty',
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            'Star stocks from search or detail pages to track them here.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg + 2),
          Center(
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StockSearchPage(
                    initialStocks: widget.stocks,
                    onSelected: widget.onStockTap,
                    onWatchlistChanged: () => unawaited(_loadWatchlist()),
                  ),
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const AppText('Search stocks'),
            ),
          ),
        ],
      );
    }

    final list = _stockList(
      _watchlistStocks,
      emptyTitle: 'Your watchlist is empty',
      emptySubtitle: 'Add stocks from search or detail pages.',
      allowPagination: false,
      requireLogo: false,
    );
    if (!_watchlistFailed) return list;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppText(
                  'Watchlist could not be refreshed. Showing previously loaded stocks.',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
              TextButton(
                onPressed: _watchlistLoading
                    ? null
                    : () => unawaited(_loadWatchlist()),
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _indicesContent() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 16.0;
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
    final yearHigh =
        widget.stocks
            .where((stock) => _yearRanges.containsKey(_instrumentKey(stock)))
            .toList()
          ..sort((left, right) {
            final leftHigh = _yearRanges[_instrumentKey(left)]!.$2;
            final rightHigh = _yearRanges[_instrumentKey(right)]!.$2;
            return ((leftHigh - left.price).abs() / leftHigh).compareTo(
              (rightHigh - right.price).abs() / rightHigh,
            );
          });
    final yearLow =
        widget.stocks
            .where((stock) => _yearRanges.containsKey(_instrumentKey(stock)))
            .toList()
          ..sort((left, right) {
            final leftLow = _yearRanges[_instrumentKey(left)]!.$1;
            final rightLow = _yearRanges[_instrumentKey(right)]!.$1;
            return ((left.price - leftLow).abs() / leftLow).compareTo(
              (right.price - rightLow).abs() / rightLow,
            );
          });
    final moverRows = switch (selectedMoverFilter) {
      0 => mostActive,
      1 => gainers,
      2 => losers,
      3 => yearHigh,
      4 => yearLow,
      _ => <StockQuote>[],
    };

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      children: [
        MarketStatusCard(
          isOpen: widget.marketOpen,
          hours: widget.marketHours,
          quotesConnected: widget.quotesConnected,
        ),
        const SizedBox(height: 14),
        _marketSectionHeading(
          'Indian Indices',
          onViewAll: () => _showIndices('Indian Indices', indices),
        ),
        const SizedBox(height: 12),
        _indexGrid(indices),
        const SizedBox(height: 18),
        _marketSectionHeading(
          'Global Indices',
          onViewAll: () => _showIndices('Global Indices', globalIndices),
        ),
        const SizedBox(height: 12),
        _indexGrid(globalIndices),
        if (_marketsFeatured.isNotEmpty) ...[
          const SizedBox(height: 18),
          _marketSectionHeading('Featured'),
          const SizedBox(height: 12),
          _moverTable(_marketsFeatured.take(5).toList()),
        ],
        const SizedBox(height: 18),
        _marketSectionHeading(
          'Market Movers',
          onViewAll: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const AppText('Market Movers')),
                body: _stockList(moverRows, emptyTitle: 'No stocks found'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _moverFilters(),
        const SizedBox(height: 8),
        _moverTable(moverRows.take(5).toList()),
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

  Widget _marketSectionHeading(
    String title, {
    bool showViewAll = true,
    VoidCallback? onViewAll,
  }) => Row(
    children: [
      Expanded(
        child: AppText(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (showViewAll && onViewAll != null)
        InkWell(
          borderRadius: AppRadius.borderSm,
          onTap: onViewAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs + 1,
            ),
            child: AppText(
              'View All',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _indexGrid(List<(String, double, double)> values) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 600 &&
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

  void _showIndices(String title, List<(String, double, double)> items) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: AppText(title)),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _indexCard(item),
                      const SizedBox(height: 12),
                      if ((_indexHistory[item.$1]?.length ?? 0) >= 2)
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _IndexSparklinePainter(
                              item.$3 >= 0 ? AppColors.gain : AppColors.loss,
                              _indexHistory[item.$1]!,
                            ),
                          ),
                        )
                      else
                        const AppText('Insufficient history'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _indexCard((String, double, double) item) {
    final available = item.$2 > 0;
    final positive = item.$3 >= 0;
    final color = !available
        ? AppColors.neutral
        : positive
        ? AppColors.gain
        : AppColors.loss;
    final history = _indexHistory[item.$1] ?? const <double>[];
    final venue = item.$1.toUpperCase().contains('SENSEX')
        ? 'BSE'
        : const {
            'DOW JONES',
            'NASDAQ',
            'S&P 500',
            'FTSE 100',
          }.contains(item.$1.toUpperCase())
        ? 'GLOBAL'
        : 'NSE';
    return AppCard(
      // Keep enough vertical room for the unavailable-quote state on narrow
      // phones; it contains both a status line and the refresh hint.
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppRadius.md,
      child: SizedBox(
        height: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(
                    item.$1,
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
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
                  )
                else
                  const Icon(
                    Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.neutral,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            AppText(
              venue,
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs + 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: AppText(
                item.$2 > 0 ? item.$2.toStringAsFixed(2) : '--',
                style: AppTypography.numericSmall.copyWith(fontSize: 15),
              ),
            ),
            AppText(
              available
                  ? '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%'
                  : 'Awaiting live quote',
              style: AppTypography.labelSmall.copyWith(
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
              SizedBox(
                height: 25,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: AppText(
                    'Data will refresh automatically',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
                  borderRadius: AppRadius.borderSm,
                  onTap: () {
                    setState(() => selectedMoverFilter = entry.key);
                    if (entry.key >= 3) unawaited(_loadYearRanges());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md + 1,
                      vertical: AppSpacing.sm + 1,
                    ),
                    decoration: BoxDecoration(
                      color: entry.key == selectedMoverFilter
                          ? AppColors.brandPrimarySoft
                          : AppColors.surface,
                      borderRadius: AppRadius.borderSm,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: AppText(
                      entry.value,
                      style: AppTypography.labelSmall.copyWith(
                        color: entry.key == selectedMoverFilter
                            ? AppColors.brandPrimary
                            : AppColors.textSecondary,
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
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg + 2),
        child: Row(
          children: [
            if (_yearRangesLoading && selectedMoverFilter >= 3)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.query_stats_rounded,
                color: AppColors.textSecondary,
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                _yearRangesLoading && selectedMoverFilter >= 3
                    ? 'Loading one-year market history...'
                    : selectedMoverFilter >= 3
                    ? 'One-year history is unavailable for these instruments.'
                    : 'No instruments match this market filter.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md - 2,
              AppSpacing.md,
              AppSpacing.sm - 1,
            ),
            child: Row(
              children: [
                const SizedBox(width: 39),
                Expanded(
                  flex: 3,
                  child: AppText(
                    'Name',
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 47),
                Expanded(
                  flex: 2,
                  child: AppText(
                    'Price',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: AppText(
                    '% Change',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  width: 55,
                  child: AppText(
                    'Volume',
                    textAlign: TextAlign.right,
                    style: AppTypography.caption.copyWith(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ...rows.map((stock) {
            final positive = stock.change >= 0;
            return InkWell(
              onTap: () => widget.onStockTap(stock),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md - 1,
                ),
                child: Row(
                  children: [
                    StockLogo(
                      symbol: stock.symbol,
                      logoUrl: stock.logoUrl,
                      size: 30,
                    ),
                    const SizedBox(width: AppSpacing.sm + 1),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            _displayStockName(stock),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          AppText(
                            stock.exchange,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
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
                                positive ? AppColors.gain : AppColors.loss,
                                _stockHistory[stock.symbol]!,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.xs + 1),
                    Expanded(
                      flex: 2,
                      child: AppText(
                        stock.price.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: AppTypography.numericSmall.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: AppText(
                        '${positive ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                        textAlign: TextAlign.right,
                        style: AppTypography.labelMedium.copyWith(
                          color: positive ? AppColors.gain : AppColors.loss,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm - 1),
                    SizedBox(
                      width: 48,
                      child: AppText(
                        formatVolume(stock.volume),
                        textAlign: TextAlign.right,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
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
      return AppCard(
        child: AppText(
          'Market breadth unavailable',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AppText(
              'Loaded instruments',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm - 1),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs + 1,
            children: [
              AppText(
                'Advances  $advances',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.gain,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppText(
                'Declines  $declines',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.loss,
                  fontWeight: FontWeight.w700,
                ),
              ),
              AppText(
                'Unchanged  $unchanged',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.neutral,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          ClipRRect(
            borderRadius: AppRadius.borderPill,
            child: Row(
              children: [
                if (advances > 0)
                  Expanded(
                    flex: advances,
                    child: Container(height: 8, color: AppColors.gain),
                  ),
                if (declines > 0)
                  Expanded(
                    flex: declines,
                    child: Container(height: 8, color: AppColors.loss),
                  ),
                if (unchanged > 0)
                  Expanded(
                    flex: unchanged,
                    child: Container(height: 8, color: AppColors.neutral),
                  ),
              ],
            ),
          ),
          AppText(
            '${(advances / total * 100).toStringAsFixed(0)}% advancing',
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketBanner() {
    return ListenableBuilder(
      listenable: AppContentService.instance,
      builder: (context, _) {
        final content = AppContentService.instance.current;
        final title = content.text(
          'home',
          'markets.banner.title',
          fallback: 'Track live markets & place orders on the go',
        );
        final subtitle = content.text(
          'home',
          'markets.banner.subtitle',
          fallback: 'Live prices, company logos and secure execution',
        );
        return AppCard(
          backgroundColor: AppColors.brandPrimarySoft,
          bordered: false,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md + 2,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      title,
                      style: AppTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      subtitle,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              const Icon(
                Icons.candlestick_chart_rounded,
                color: AppColors.gain,
                size: 50,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stockList(
    List<StockQuote> stocks, {
    required String emptyTitle,
    String emptySubtitle = 'Try a different search or market filter.',
    bool allowPagination = true,
    bool requireLogo = true,
  }) {
    stocks = stocks
        .where(
          (stock) =>
              !requireLogo ||
              (stock.logoUrl?.trim().isNotEmpty == true &&
                  !_failedLogoUrls.contains(stock.logoUrl)),
        )
        .toList();
    if (_searchLoading && stocks.isEmpty) {
      return const AppLoadingView();
    }
    if (allowPagination && _searchFailed && stocks.isEmpty) {
      return _emptyState(
        Icons.cloud_off,
        'Market data unavailable',
        'Network error or live search is unavailable. Please refresh to try again.',
      );
    }
    if (stocks.isEmpty && !(allowPagination && _searchHasMore)) {
      return _emptyState(
        Icons.search_off,
        emptyTitle,
        requireLogo
            ? '$emptySubtitle Only stocks with available logos are shown. Refresh to retry.'
            : emptySubtitle,
      );
    }

    final showMore = allowPagination && (_searchHasMore || _searchFailed);
    return ListView.separated(
      key: PageStorageKey('market-list-$selectedTab'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppSpacing.page,
      itemCount: stocks.length + (showMore ? 1 : 0),
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        if (index == stocks.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: OutlinedButton(
                onPressed: _searchLoading
                    ? null
                    : () => _searchStocks(
                        reset: _searchFailed && _failedSearchWasReset,
                      ),
                child: _searchLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : AppText(
                        _searchFailed
                            ? 'Unable to load stocks. Retry'
                            : 'Load more',
                      ),
              ),
            ),
          );
        }

        final stock = stocks[index];
        return StockListTile(
          key: ValueKey('${stock.exchange}:${stock.symbol}:${stock.logoUrl}'),
          stock: stock,
          onLogoLoadFailed: () {
            if (!mounted ||
                stock.logoUrl == null ||
                _failedLogoUrls.contains(stock.logoUrl)) {
              return;
            }
            setState(() => _failedLogoUrls.add(stock.logoUrl!));
          },
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
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: AppColors.textTertiary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppText(
                'Sector classifications are currently unavailable.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          'Sector Constituents',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.md - 2),
        ...rows.take(12).map((row) {
          final symbols = row.value
              .map((stock) => stock.symbol)
              .take(4)
              .join(', ');
          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.category_outlined,
                color: AppColors.brandPrimary,
              ),
              title: AppText(row.key, style: AppTypography.titleSmall),
              subtitle: AppText(
                symbols,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: AppText(
                '${row.value.length}',
                style: AppTypography.labelMedium,
              ),
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
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      children: [
        const SizedBox(height: 100),
        Icon(icon, size: 64, color: AppColors.textTertiary),
        const SizedBox(height: AppSpacing.lg),
        AppText(
          title,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppText(
          subtitle,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg + 2),
        Center(
          child: OutlinedButton.icon(
            onPressed: _searchLoading ? null : _refreshAll,
            icon: _searchLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const AppText('Refresh market data'),
          ),
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
