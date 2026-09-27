part of 'market_page.dart';

extension _MarketHomeMarketActions on _MarketHomePageState {
  Future<void> _reloadNews() async {
    final latest = await marketDataService.fetchMarketNews();
    if (!mounted) return;
    if (latest.isNotEmpty) {
      _updateState(() {
        marketNews
          ..clear()
          ..addAll(latest);
      });
    }
  }

  Future<void> _openNews(MarketNewsItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      _showNewsOpenError();
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showNewsOpenError();
    } catch (_) {
      _showNewsOpenError();
    }
  }

  Future<void> _openAllMarketNews() async {
    final latest = await marketDataService.fetchMarketNews(limit: 50);
    if (!mounted) return;
    final items = latest.isNotEmpty
        ? latest
        : List<MarketNewsItem>.from(marketNews);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketNewsPage(
          items: items,
          onOpen: _openNews,
          onRefresh: () => marketDataService.fetchMarketNews(limit: 50),
        ),
      ),
    );
  }

  void _showNewsOpenError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: AppText('Unable to open this news article')),
      );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));
    await _refreshUnreadNotificationCount();
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final notifications = await ClientAccountService().notifications();
      if (!mounted) return;
      _updateState(() {
        unreadNotificationCount = notifications
            .where((item) => item['readAt'] == null)
            .length;
      });
    } catch (_) {
      // Preserve the current badge when the server cannot be reached.
    }
  }

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: unreadNotificationCount > 0
              ? 'Notifications ($unreadNotificationCount unread)'
              : 'Notifications',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
        ),
        if (unreadNotificationCount > 0)
          Positioned(
            right: 7,
            top: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEF233C),
                shape: BoxShape.circle,
              ),
              child: AppText(
                unreadNotificationCount > 9
                    ? '9+'
                    : unreadNotificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openHomeIndex(HomeIndexQuote item) {
    final ref =
        MarketIndexRef.byLabel(item.label) ??
        MarketIndexRef(
          label: item.label,
          symbol: item.label.replaceAll(' ', ''),
          exchange: 'NSE',
          venue: 'NSE',
        );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => IndexDetailPage(
          quote: MarketIndexQuote(
            ref: ref,
            price: item.price,
            changePercent: item.changePercent,
            history: item.history,
          ),
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        ),
      ),
    );
  }

  void _openStock(StockQuote stock) {
    _openStockForTrade(stock, isBuy: true);
  }

  void _openStockForTrade(StockQuote stock, {required bool isBuy}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StockDetailPage(
          stock: stock,
          onOrderPlaced: _placeOrder,
          initialIsBuy: isBuy,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        ),
      ),
    );
  }

  void _openStockSearch() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StockSearchPage(initialStocks: stocks, onSelected: _openStock),
      ),
    );
  }

  Future<String?> _placeOrder(TradingOrder order) async {
    final existing = positions[_positionKey(order.exchange, order.symbol)];

    if (order.isBuy && order.amount > buyingPower) {
      return 'Insufficient buying power. Available: '
          '${formatPrice(buyingPower)}';
    }

    if (!order.isBuy &&
        (existing == null || existing.availableQuantity < order.quantity)) {
      return 'Insufficient holdings. Available: '
          '${existing?.availableQuantity ?? 0}';
    }

    try {
      final confirmedOrder = await tradingService.placeMarketOrder(order);
      final snapshot = await tradingService
          .fetchAccountSnapshot(allowCached: false)
          .catchError((_) => null);
      final remoteOrders = await tradingService
          .fetchOrders(allowCached: false)
          .catchError((_) => <TradingOrder>[]);
      if (!mounted) return null;
      final updatedOrders = mergeConfirmedOrder(
        confirmedOrder,
        remoteOrders.isNotEmpty ? remoteOrders : orders,
      );

      if (snapshot != null) {
        _updateState(() {
          _applyAccountSnapshot(snapshot);
          orders
            ..clear()
            ..addAll(updatedOrders);
        });

        return null;
      }

      _updateState(() {
        orders
          ..clear()
          ..addAll(updatedOrders);
      });

      return null;
    } catch (error) {
      return error.toString();
    }
  }
}
