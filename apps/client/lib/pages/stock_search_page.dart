import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../services/market_data_service.dart';
import '../services/logo_market_page.dart';
import '../services/watchlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_feedback.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/stock_list_tile.dart';

class StockSearchPage extends StatefulWidget {
  const StockSearchPage({
    super.key,
    required this.initialStocks,
    required this.onSelected,
    this.onWatchlistChanged,
    this.marketDataService,
    this.watchlistService,
  });

  final List<StockQuote> initialStocks;
  final ValueChanged<StockQuote> onSelected;
  final VoidCallback? onWatchlistChanged;
  final MarketDataService? marketDataService;
  final WatchlistService? watchlistService;

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends State<StockSearchPage> {
  final _controller = TextEditingController();
  late final _marketData = widget.marketDataService ?? MarketDataService();
  late final _watchlistService = widget.watchlistService ?? WatchlistService();
  Timer? _debounce;
  List<StockQuote> _results = const [];
  bool _loading = false;
  bool _failed = false;
  bool _failedLoadMore = false;
  String? _resultQuery;
  int _generation = 0;
  int _page = 0;
  bool _hasMore = false;
  final Set<String> _failedLogos = {};
  Set<String> _watchlist = <String>{};
  final Set<String> _watchlistSaving = <String>{};
  bool _watchlistLoading = true;
  bool _watchlistFailed = false;

  @override
  void initState() {
    super.initState();
    _results = widget.initialStocks;
    _loadWatchlist();
    unawaited(_search(''));
  }

  Future<void> _loadWatchlist() async {
    if (_watchlistSaving.isNotEmpty) return;
    setState(() => _watchlistLoading = true);
    try {
      final values = await _watchlistService.fetchSymbols();
      if (!mounted) return;
      setState(() {
        _watchlist = values;
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

  Future<void> _toggleWatchlist(StockQuote stock) async {
    final key = WatchlistService.key(stock.exchange, stock.symbol);
    if (_watchlistLoading ||
        _watchlistFailed ||
        _watchlistSaving.contains(key)) {
      return;
    }
    final removing = _watchlist.contains(key);
    setState(() => _watchlistSaving.add(key));
    try {
      if (removing) {
        await _watchlistService.remove(stock.symbol, exchange: stock.exchange);
      } else {
        await _watchlistService.add(stock.symbol, exchange: stock.exchange);
      }
      if (!mounted) return;
      setState(() {
        if (removing) {
          _watchlist.remove(key);
        } else {
          _watchlist.add(key);
        }
      });
      widget.onWatchlistChanged?.call();
    } on WatchlistException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to update watchlist')),
      );
    } finally {
      if (mounted) setState(() => _watchlistSaving.remove(key));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    _generation++;
    // Rebuild immediately so the clear action reflects the current query
    // while the debounced request is in flight.
    setState(() {
      _failed = false;
      _failedLoadMore = false;
      _results = const [];
      _resultQuery = null;
      _hasMore = false;
      _loading = true;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(query));
  }

  void _submitSearch(String value) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    unawaited(_search(value.trim()));
  }

  Future<void> _search(String query, {bool loadMore = false}) async {
    if (loadMore && (_loading || !_hasMore)) return;
    final generation = loadMore ? _generation : ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await loadLogoMarketPage(
        page: loadMore ? _page + 1 : 1,
        fetch: (page) =>
            _marketData.searchSnapshot(query: query, pageSize: 100, page: page),
        failedUrls: _failedLogos,
        isCurrent: () => mounted && generation == _generation,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        final merged = <String, StockQuote>{
          if (loadMore)
            for (final stock in _results)
              WatchlistService.key(stock.exchange, stock.symbol): stock,
          for (final stock in response.data)
            WatchlistService.key(stock.exchange, stock.symbol): stock,
        };
        _results = merged.values.toList();
        _resultQuery = query;
        _failedLoadMore = false;
        _page = response.page;
        _hasMore = response.hasMore;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      final needle = query.toLowerCase();
      setState(() {
        _failed = true;
        _failedLoadMore = loadMore;
        if (!loadMore && _resultQuery != query) {
          _results = widget.initialStocks
              .where(
                (stock) =>
                    stock.symbol.toLowerCase().contains(needle) ||
                    stock.name.toLowerCase().contains(needle),
              )
              .toList();
        }
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(StockQuote stock) {
    Navigator.pop(context);
    widget.onSelected(stock);
  }

  Future<void> _retrySearch() async {
    if (_loading) return;
    _debounce?.cancel();
    _failedLogos.clear();
    await _search(
      _controller.text.trim(),
      loadMore: _failed && _failedLoadMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _results
        .where(
          (stock) =>
              stock.logoUrl?.trim().isNotEmpty == true &&
              !_failedLogos.contains(stock.logoUrl),
        )
        .toList();
    return AppPageScaffold(
      appBar: AppBar(
        title: const AppText('Search stocks'),
        actions: [
          IconButton(
            tooltip: tr('Refresh'),
            onPressed: _loading ? null : _retrySearch,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Semantics(
              textField: true,
              label: tr('Search stocks'),
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                onChanged: _onChanged,
                onSubmitted: _submitSearch,
                decoration: InputDecoration(
                  hintText: tr('Search symbol or company'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  constraints: const BoxConstraints(
                    minHeight: AppMotion.tapTarget,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm,
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderSm,
                    borderSide: const BorderSide(color: AppColors.brandPrimary),
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('Clear'),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_watchlistFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: AppText('Unable to load watchlist')),
                  TextButton(
                    onPressed: _watchlistLoading ? null : _loadWatchlist,
                    child: const AppText('Retry'),
                  ),
                ],
              ),
            ),
          if (_failed && visible.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm + 2,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppText(
                      _failedLoadMore
                          ? 'More results could not be loaded. Your current results are still available.'
                          : 'Live search is unavailable. Showing loaded instruments.',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _retrySearch,
                    child: const AppText('Retry'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AppFadeIn(
              switchKey: '$_resultQuery:$_loading:$_failed:${visible.length}',
              child: visible.isEmpty && _loading
                  ? const AppLoadingView(message: 'Searching stocks…')
                  : visible.isEmpty && !_hasMore
                  ? (_failed
                        ? AppErrorView(
                            title: 'Unable to load stocks',
                            message:
                                'Search is temporarily unavailable. Please retry.',
                            onRetry: _retrySearch,
                          )
                        : AppEmptyState(
                            title: _controller.text.trim().isEmpty
                                ? 'No instruments available'
                                : 'No matching stocks',
                            message: _controller.text.trim().isEmpty
                                ? 'Try again when market data is available.'
                                : 'Try a different symbol or company name.',
                            icon: Icons.search_off,
                            onRetry: _retrySearch,
                          ))
                  : ListView.builder(
                      key: ValueKey(_controller.text.trim()),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      itemCount: visible.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == visible.length) {
                          return Center(
                            child: TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => _search(
                                      _controller.text.trim(),
                                      loadMore: true,
                                    ),
                              child: AppText(
                                _loading
                                    ? 'Loading…'
                                    : _failedLoadMore
                                    ? 'Retry'
                                    : 'Load more',
                              ),
                            ),
                          );
                        }
                        final stock = visible[index];
                        final key = WatchlistService.key(
                          stock.exchange,
                          stock.symbol,
                        );
                        return StockListTile(
                          key: ValueKey(key),
                          stock: stock,
                          onLogoLoadFailed: () {
                            if (!mounted ||
                                stock.logoUrl == null ||
                                _failedLogos.contains(stock.logoUrl)) {
                              return;
                            }
                            setState(() => _failedLogos.add(stock.logoUrl!));
                          },
                          onTap: () => _select(stock),
                          isFavorite: _watchlist.contains(key),
                          onFavorite:
                              _watchlistLoading ||
                                  _watchlistFailed ||
                                  _watchlistSaving.contains(key)
                              ? null
                              : () => _toggleWatchlist(stock),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
