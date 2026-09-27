part of 'stock_detail_page.dart';

extension _StockDetailDataSection on _StockDetailPageState {
  Future<void> _loadAccountSnapshot() async {
    try {
      final snapshot = await _tradingService.fetchAccountSnapshot();
      if (!mounted || snapshot == null) return;
      _setState(() => accountSnapshot = snapshot);
    } catch (_) {
      // Order ticket stays available; buying-power hints remain hidden.
    }
  }

  Future<void> _loadYearStats() async {
    try {
      final history = await MarketDataService().fetchHistory(
        symbol: liveStock.symbol,
        exchange: liveStock.exchange,
        range: '1Y',
      );
      if (!mounted) return;
      _setState(() {
        yearHistory = history.data.length >= 2 ? history : yearHistory;
        yearHistoryFailed = history.data.length < 2;
      });
    } catch (_) {
      if (mounted) _setState(() => yearHistoryFailed = true);
    }
  }

  Future<void> _loadRelatedNews() async {
    if (!newsLoading || newsFailed) {
      _setState(() {
        newsLoading = true;
        newsFailed = false;
      });
    }
    try {
      final items = await MarketDataService().fetchMarketNews(limit: 50);
      if (!mounted) return;
      _setState(() {
        relatedNews = newsMentioningInstrument(items, liveStock);
        newsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _setState(() {
        newsLoading = false;
        newsFailed = true;
      });
    }
  }

  Future<void> _openNews(MarketNewsItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to open this news article')),
      );
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('Unable to open this news article')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('Unable to open this news article')),
      );
    }
  }

  Future<void> _loadWatchlistState() async {
    try {
      final symbols = await watchlistService.fetchSymbols();
      if (!mounted) return;
      _setState(() {
        isWatched = symbols.contains(
          WatchlistService.key(liveStock.exchange, liveStock.symbol),
        );
        watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _setState(() => watchlistLoading = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    if (watchlistLoading || watchlistSaving) return;
    final next = !isWatched;
    _setState(() {
      isWatched = next;
      watchlistSaving = true;
    });

    try {
      if (next) {
        await watchlistService.add(
          liveStock.symbol,
          exchange: liveStock.exchange,
        );
      } else {
        await watchlistService.remove(
          liveStock.symbol,
          exchange: liveStock.exchange,
        );
      }
      if (!mounted) return;
      _setState(() => watchlistSaving = false);
      _showMessage(next ? 'Added to watchlist' : 'Removed from watchlist');
    } catch (_) {
      if (!mounted) return;
      _setState(() {
        isWatched = !next;
        watchlistSaving = false;
      });
      _showMessage('Unable to update watchlist');
    }
  }

  void _handleConnectionUpdate(bool connected) {
    if (!mounted || socketConnected == connected) return;
    _setState(() => socketConnected = connected);
  }

  void _handleQuoteUpdate(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString().trim().toUpperCase();
    if (symbol != liveStock.symbol) return;
    final exchange = data['exchange']?.toString().trim().toUpperCase();
    if (exchange != null &&
        exchange.isNotEmpty &&
        exchange != liveStock.exchange) {
      return;
    }

    final price = double.tryParse(data['price']?.toString() ?? '');
    if (price == null || price <= 0 || !mounted) return;
    final direction = price.compareTo(liveStock.price);

    final updated = StockQuote.applyRealtime(liveStock, data);
    if (updated == null) return;
    _setState(() {
      priceDirection = direction;
      liveStock = updated;
    });
    priceFlashTimer?.cancel();
    if (direction != 0) {
      priceFlashTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) _setState(() => priceDirection = 0);
      });
    }
  }
}

