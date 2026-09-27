import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/async_data_state.dart';
import '../models/stock_quote.dart';
import '../services/app_content_service.dart';
import '../services/featured_instruments_service.dart';
import '../services/market_data_service.dart';
import '../services/logo_market_page.dart';
import '../services/market_socket_service.dart';
import '../services/watchlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/client_error_message.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';
import '../widgets/home/home_dashboard_data.dart';
import '../widgets/markets/browse_only_banner.dart';
import '../widgets/markets/market_index_ref.dart';
import '../widgets/markets/markets_index_card.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_list_tile.dart';
import '../widgets/market_status_card.dart';
import 'index_detail_page.dart';
import 'index_list_page.dart';
import 'movers_list_page.dart';
import 'stock_search_page.dart';

part 'markets_page_indices_section.dart';
part 'markets_page_content_section.dart';

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
  void _updateState(VoidCallback update) => setState(update);

  String _marketCopy(String key, String fallback) =>
      AppContentService.instance.current.text('home', key, fallback: fallback);

  final MarketDataService _marketDataService = MarketDataService();
  final WatchlistService _watchlistService = WatchlistService();
  final MarketSocketService _marketSocket = MarketSocketService();
  int selectedTab = 1;
  int selectedMoverFilter = 0;
  String query = '';
  List<StockQuote> _remoteSearchResults = <StockQuote>[];
  AsyncDataState<List<StockQuote>> _watchlistState =
      const AsyncDataState.loading();
  bool _searchLoading = false;
  bool _searchFailed = false;
  bool _failedSearchWasReset = true;
  bool _searchHasMore = false;
  final Map<String, List<double>> _indexHistory = <String, List<double>>{};
  final List<StockQuote> _marketsFeatured = <StockQuote>[];
  final Map<String, (double, double)> _yearRanges =
      <String, (double, double)>{};
  bool _yearRangesLoading = false;
  int _searchPage = 1;
  int _searchGeneration = 0;

  List<StockQuote> get _watchlistStocks =>
      _watchlistState.data ?? const <StockQuote>[];
  bool get _watchlistLoading => _watchlistState.isLoading;
  bool get _watchlistFailed =>
      _watchlistState.status == AsyncDataStatus.error ||
      _watchlistState.requiresNotice;

  static const _foKeywords = ['F&O', 'FUTURE', 'OPTION', 'DERIVATIVE'];
  static const _commodityKeywords = ['COMMODITY', 'MCX', 'METAL', 'ENERGY'];
  static const _currencyKeywords = ['CURRENCY', 'FOREX', 'FX'];

  /// Always-visible core tabs, then optional catalog tabs when instruments exist.
  List<(int contentIndex, String label)> get _visibleTabs {
    final tabs = <(int, String)>[(1, 'Indices'), (2, 'Stocks'), (3, 'Sectors')];
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
    tabs.add((0, 'Watchlist'));
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
    AppContentService.instance.addListener(_onContentChanged);
    _loadWatchlist();
    unawaited(_loadIndexHistory());
    unawaited(_loadFeaturedStocks());
    unawaited(_searchStocks(reset: true));
    unawaited(AppContentService.instance.load());
  }

  Future<void> _loadFeaturedStocks() async {
    final featured = await FeaturedInstrumentsService.instance
        .marketsFeatured();
    if (!mounted) return;
    setState(() {
      _marketsFeatured
        ..clear()
        ..addAll(featured);
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
    AppContentService.instance.removeListener(_onContentChanged);
    _marketSocket.removeQuoteListener(_handleRealtimeQuote);
    super.dispose();
  }

  void _onContentChanged() {
    if (mounted) setState(() {});
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
    final previousState = _watchlistState;
    if (mounted) {
      setState(() {
        _watchlistState = AsyncDataState.loading(
          data: previousState.data,
          updatedAt: previousState.updatedAt,
        );
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
        _watchlistState = AsyncDataState.success(stocks);
      });
    } catch (error) {
      if (!mounted) return;
      final message = clientErrorMessage(error);
      setState(() {
        final previousStocks = _watchlistState.data;
        _watchlistState = previousStocks == null
            ? AsyncDataState.error(message)
            : AsyncDataState.stale(
                previousStocks,
                updatedAt: _watchlistState.updatedAt ?? DateTime.now(),
                message: message,
              );
      });
    }
  }

  Future<void> _refreshAll() async {
    _failedLogoUrls.clear();
    await Future.wait([
      widget.onRefresh(),
      AppContentService.instance.load(force: true),
    ]);
    await _loadWatchlist();
    await _loadIndexHistory();
    await _loadFeaturedStocks();
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
                  IconButton(
                    tooltip: tr('Search stocks'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StockSearchPage(
                          initialStocks: widget.stocks,
                          onSelected: widget.onStockTap,
                          onWatchlistChanged: () => unawaited(_loadWatchlist()),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.search_rounded),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: tr('Notifications'),
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
                AppSpacing.sm,
              ),
              child: MarketStatusCard(
                isOpen: widget.marketOpen,
                hours: widget.marketHours,
                quotesConnected: widget.quotesConnected,
              ),
            ),
            if (quotesAreStale(widget.stocks) ||
                widget.quotesConnected == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: AppText(
                  homeQuoteFreshnessLabel(
                    updatedAt: latestQuoteUpdatedAt(widget.stocks),
                    quotesConnected: widget.quotesConnected != false,
                    stale: true,
                  ),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            DecoratedBox(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                height: AppMotion.tapTarget + 4,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
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
                          constraints: const BoxConstraints(
                            minHeight: AppMotion.tapTarget,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.brandPrimarySoft
                                : Colors.transparent,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.sm),
                            ),
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
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: AppFadeIn(
                    switchKey: effectiveTab,
                    child: _selectedContent(contentIndex: effectiveTab),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          radius: AppRadius.sm,
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
    String? browseOnlyLabel,
  }) {
    stocks = stocks
        .where(
          (stock) =>
              !requireLogo ||
              (stock.logoUrl?.trim().isNotEmpty == true &&
                  !_failedLogoUrls.contains(stock.logoUrl)),
        )
        .toList();
    Widget wrapBrowse(Widget child) {
      if (browseOnlyLabel == null) return child;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: BrowseOnlyBanner(productLabel: browseOnlyLabel),
          ),
          Expanded(child: child),
        ],
      );
    }

    if (_searchLoading && stocks.isEmpty) {
      return wrapBrowse(
        AppLoadingView(
          message: _marketCopy('markets.loading', 'Loading markets…'),
        ),
      );
    }
    if (allowPagination && _searchFailed && stocks.isEmpty) {
      return wrapBrowse(
        _emptyState(
          Icons.cloud_off,
          _marketCopy('markets.search_error_title', 'Market data unavailable'),
          _marketCopy(
            'markets.search_error_body',
            'Network error or live search is unavailable. Please refresh to try again.',
          ),
        ),
      );
    }
    if (stocks.isEmpty && !(allowPagination && _searchHasMore)) {
      return wrapBrowse(
        _emptyState(
          Icons.search_off,
          emptyTitle,
          requireLogo
              ? '$emptySubtitle Only stocks with available logos are shown. Refresh to retry.'
              : emptySubtitle,
        ),
      );
    }

    final showMore = allowPagination && (_searchHasMore || _searchFailed);
    return wrapBrowse(
      ListView.separated(
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Loading more stocks',
                          ),
                        )
                      : AppText(
                          _searchFailed
                              ? _marketCopy(
                                  'markets.load_more_retry',
                                  'Unable to load stocks. Retry',
                                )
                              : _marketCopy('markets.load_more', 'Load more'),
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
      ),
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
      browseOnlyLabel: 'ETFs',
    );
  }

  Widget _categoryList(
    List<String> keywords, {
    required String emptyTitle,
    required String emptySubtitle,
    String? browseOnlyLabel,
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
      browseOnlyLabel: browseOnlyLabel,
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
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: 'Refreshing market data',
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: AppText(
              _marketCopy('markets.refresh', 'Refresh market data'),
            ),
          ),
        ),
      ],
    );
  }
}
