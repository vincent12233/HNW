part of 'trading_center_page.dart';

extension _TradingCenterPageDataLifecycle on _TradingCenterPageState {
  Future<void> _refreshTradingData({bool ensureAfterCurrent = false}) async {
    final current = _refreshInFlight;
    if (current != null) {
      await current;
      if (!ensureAfterCurrent) return;
    }

    final afterWait = _refreshInFlight;
    if (afterWait != null) {
      await afterWait;
      return;
    }

    final refresh = _performTradingRefresh();
    _refreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) {
        _refreshInFlight = null;
      }
      _scheduleNextRefresh();
    }
  }

  void _scheduleNextRefresh() {
    if (!mounted) return;
    _refreshTimer?.cancel();
    final hasActiveOrders = _orders.any(
      (order) => order.status == 'OPEN' || order.status == 'PARTIALLY_FILLED',
    );
    _refreshTimer = Timer(
      hasActiveOrders
          ? const Duration(seconds: 5)
          : const Duration(seconds: 30),
      () => unawaited(_refreshTradingData()),
    );
  }

  Future<void> _performTradingRefresh() async {
    if (!mounted) return;
    await AppContentService.instance.load(force: true);
    _setState(() => _transactionsLoading = true);
    final previousById = <String, TradingOrder>{
      for (final order in _orders)
        if (order.orderId?.isNotEmpty == true) order.orderId!: order,
    };
    final results = await Future.wait<Object?>([
      _tradingService
          .fetchOrders(allowCached: false)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _tradingService
          .fetchAccountSnapshot(allowCached: false)
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _tradingService
          .fetchTransactions()
          .then<Object?>((value) => value)
          .catchError((_) => null),
    ]);
    if (!mounted) return;

    final latestOrders = results[0] as List<TradingOrder>?;
    final snapshot = results[1] as TradingAccountSnapshot?;
    final transactions = results[2] as List<AccountTransaction>?;

    _setState(() {
      _transactionsLoading = false;
      _transactionsFailed = transactions == null;
      _ordersFailed = latestOrders == null;
      _accountFailed = snapshot == null;
      if (latestOrders != null) {
        _orders
          ..clear()
          ..addAll(latestOrders);
      }
      if (snapshot != null) {
        _accountSnapshot = snapshot;
        _positions
          ..clear()
          ..addEntries(
            snapshot.positions.map(
              (position) =>
                  MapEntry('${position.exchange}:${position.symbol}', position),
            ),
          );
      }
      if (transactions != null) {
        _transactions
          ..clear()
          ..addAll(transactions);
      }
    });
    if (latestOrders != null) {
      _announceOrderChanges(previousById, latestOrders);
    }
  }

  void _announceOrderChanges(
    Map<String, TradingOrder> previousById,
    List<TradingOrder> latestOrders,
  ) {
    for (final latest in latestOrders) {
      final id = latest.orderId;
      if (id == null) continue;
      final previous = previousById[id];
      if (previous == null ||
          (previous.status == latest.status &&
              previous.filledQuantity == latest.filledQuantity)) {
        continue;
      }
      final message = latest.status == 'PARTIALLY_FILLED'
          ? '${latest.exchange}:${latest.symbol} filled '
                '${latest.filledQuantity}/${latest.quantity}'
          : '${latest.exchange}:${latest.symbol} order '
                '${latest.status.toLowerCase().replaceAll('_', ' ')}';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: AppText(message)));
      break;
    }
  }

  Future<String?> _cancelStandardOrder(TradingOrder order) async {
    final orderId = order.orderId;
    if (orderId == null || orderId.isEmpty) {
      return 'Order reference is unavailable';
    }
    if (_cancellingOrderIds.contains(orderId)) {
      return 'Cancellation is already in progress';
    }

    _cancellingOrderIds.add(orderId);
    try {
      await _tradingService.cancelOrder(orderId);
      await _refreshTradingData(ensureAfterCurrent: true);
      return null;
    } on TradingException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    } finally {
      _cancellingOrderIds.remove(orderId);
    }
  }

  List<TradingOrder> get _openAndPendingOrders => _orders
      .where(
        (order) =>
            order.status == 'OPEN' ||
            order.status == 'PARTIALLY_FILLED' ||
            order.status == 'PENDING',
      )
      .toList();

}
