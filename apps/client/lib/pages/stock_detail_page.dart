import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../models/market_history.dart';
import '../models/market_news_item.dart';
import '../models/stock_quote.dart';
import '../models/trading_order.dart';
import '../services/market_socket_service.dart';
import '../services/market_data_service.dart';
import '../services/trading_service.dart';
import '../services/watchlist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/markets/browse_only_banner.dart';
import '../widgets/markets/instrument_browse.dart';
import '../widgets/markets/instrument_news.dart';
import '../widgets/markets/news_article_sheet.dart';
import '../widgets/markets/stock_quote_hero.dart';
import '../widgets/stock_history_chart.dart';

class StockDetailPage extends StatefulWidget {
  const StockDetailPage({
    super.key,
    required this.stock,
    required this.onOrderPlaced,
  });

  final StockQuote stock;
  final Future<String?> Function(TradingOrder) onOrderPlaced;

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  final quantityController = TextEditingController(text: '1');
  final limitPriceController = TextEditingController();
  final marketSocket = MarketSocketService();
  final watchlistService = WatchlistService();

  late StockQuote liveStock;
  bool isBuy = true;
  bool isSubmitting = false;
  bool isWatched = false;
  bool watchlistLoading = true;
  bool watchlistSaving = false;
  String orderType = 'MARKET';
  String timeInForce = 'DAY';
  String? _pendingClientOrderId;
  String? _pendingOrderFingerprint;
  late bool socketConnected;
  Timer? freshnessTimer;
  Timer? priceFlashTimer;
  int priceDirection = 0;
  MarketHistorySeries? yearHistory;
  bool yearHistoryFailed = false;
  List<MarketNewsItem> relatedNews = [];
  bool newsLoading = true;
  bool newsFailed = false;
  TradingAccountSnapshot? accountSnapshot;

  bool get _browseOnly => isBrowseOnlyInstrument(liveStock);

  bool get isLimit => orderType == 'LIMIT';

  bool get orderQuoteReady =>
      liveStock.quoteFresh &&
      DateTime.now().difference(liveStock.updatedAt) <=
          const Duration(minutes: 2) &&
      selectedOrderPrice > 0;

  double get selectedOrderPrice {
    if (!isLimit) {
      return isBuy
          ? (liveStock.ask ?? liveStock.price)
          : (liveStock.bid ?? liveStock.price);
    }
    return double.tryParse(limitPriceController.text.trim()) ?? 0;
  }

  double get estimatedAmount {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    return quantity * selectedOrderPrice;
  }

  int? get maxBuyQuantity {
    final buyingPower = accountSnapshot?.buyingPower;
    final price = selectedOrderPrice;
    if (buyingPower == null || buyingPower <= 0 || price <= 0) return null;
    return buyingPower ~/ price;
  }

  int? get availableSellQuantity {
    final snapshot = accountSnapshot;
    if (snapshot == null) return null;
    var available = 0;
    for (final position in snapshot.positions) {
      if (position.symbol.trim().toUpperCase() == liveStock.symbol &&
          position.exchange.trim().toUpperCase() == liveStock.exchange) {
        available += position.availableQuantity;
      }
    }
    return available;
  }

  double? get limitDeviationPercent {
    if (!isLimit || selectedOrderPrice <= 0 || liveStock.price <= 0) {
      return null;
    }
    return (selectedOrderPrice - liveStock.price) / liveStock.price * 100;
  }

  @override
  void initState() {
    super.initState();
    liveStock = widget.stock;
    socketConnected = marketSocket.isConnected;
    limitPriceController.text = liveStock.price.toStringAsFixed(2);
    marketSocket.addQuoteListener(_handleQuoteUpdate);
    marketSocket.addConnectionListener(_handleConnectionUpdate);
    freshnessTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    _loadWatchlistState();
    _loadYearStats();
    _loadAccountSnapshot();
    unawaited(_loadRelatedNews());
  }

  Future<void> _loadAccountSnapshot() async {
    try {
      final snapshot = await TradingService().fetchAccountSnapshot();
      if (!mounted || snapshot == null) return;
      setState(() => accountSnapshot = snapshot);
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
      setState(() {
        yearHistory = history.data.length >= 2 ? history : yearHistory;
        yearHistoryFailed = history.data.length < 2;
      });
    } catch (_) {
      if (mounted) setState(() => yearHistoryFailed = true);
    }
  }

  Future<void> _loadRelatedNews() async {
    if (!newsLoading || newsFailed) {
      setState(() {
        newsLoading = true;
        newsFailed = false;
      });
    }
    try {
      final items = await MarketDataService().fetchMarketNews(limit: 50);
      if (!mounted) return;
      setState(() {
        relatedNews = newsMentioningInstrument(items, liveStock);
        newsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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
      setState(() {
        isWatched = symbols.contains(
          WatchlistService.key(liveStock.exchange, liveStock.symbol),
        );
        watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => watchlistLoading = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    if (watchlistLoading || watchlistSaving) return;
    final next = !isWatched;
    setState(() {
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
      setState(() => watchlistSaving = false);
      _showMessage(next ? 'Added to watchlist' : 'Removed from watchlist');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isWatched = !next;
        watchlistSaving = false;
      });
      _showMessage('Unable to update watchlist');
    }
  }

  void _handleConnectionUpdate(bool connected) {
    if (!mounted || socketConnected == connected) return;
    setState(() => socketConnected = connected);
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
    setState(() {
      priceDirection = direction;
      liveStock = updated;
    });
    priceFlashTimer?.cancel();
    if (direction != 0) {
      priceFlashTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => priceDirection = 0);
      });
    }
  }

  @override
  void dispose() {
    marketSocket.removeQuoteListener(_handleQuoteUpdate);
    marketSocket.removeConnectionListener(_handleConnectionUpdate);
    freshnessTimer?.cancel();
    priceFlashTimer?.cancel();
    quantityController.dispose();
    limitPriceController.dispose();
    super.dispose();
  }

  void placeOrder() {
    if (_browseOnly) return;
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final limitPrice = isLimit
        ? double.tryParse(limitPriceController.text.trim())
        : null;

    if (quantity <= 0) {
      _showMessage('Please enter a valid quantity');
      return;
    }
    if (isLimit && (limitPrice == null || limitPrice <= 0)) {
      _showMessage('Please enter a valid limit price');
      return;
    }
    if (!orderQuoteReady) {
      _showMessage('Current market quote is unavailable. Please refresh.');
      marketSocket.refreshSnapshot();
      return;
    }

    final priceLabel = isLimit
        ? 'Limit price: ${formatPrice(limitPrice!)}'
        : 'Indicative price: ${formatPrice(selectedOrderPrice)}';
    final quoteDelayed =
        !socketConnected ||
        !liveStock.quoteFresh ||
        DateTime.now().difference(liveStock.updatedAt) >
            const Duration(minutes: 2);
    final quoteNotice = quoteDelayed
        ? '\n\nMarket price may be delayed. Review the order price before confirming.'
        : '';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText(isBuy ? 'Confirm Buy' : 'Confirm Sell'),
        content: AppText(
          '${isBuy ? 'Buy' : 'Sell'} $quantity shares of ${liveStock.symbol}\n\n'
          '${isLimit ? 'Limit Order' : 'Market Order'} • $timeInForce\n'
          '$priceLabel\n\n'
          'Estimated amount: ${formatPrice(estimatedAmount)}'
          '$quoteNotice',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setState(() => isSubmitting = true);
                    final draft = TradingOrder(
                      symbol: liveStock.symbol,
                      exchange: liveStock.exchange,
                      isBuy: isBuy,
                      quantity: quantity,
                      price: selectedOrderPrice,
                      placedAt: DateTime.now(),
                      type: orderType,
                      timeInForce: timeInForce,
                      limitPrice: limitPrice,
                    );
                    final fingerprint = draft.submissionFingerprint();
                    if (_pendingOrderFingerprint != fingerprint) {
                      _pendingClientOrderId = null;
                      _pendingOrderFingerprint = fingerprint;
                    }
                    _pendingClientOrderId ??=
                        TradingService.createClientOrderId(
                          exchange: draft.exchange,
                          symbol: draft.symbol,
                        );
                    final order = draft.withClientOrderId(
                      _pendingClientOrderId!,
                    );

                    TradingService.clearLastPlacedOrder();
                    final errorMessage = await widget.onOrderPlaced(order);
                    final confirmedOrder = TradingService.takeLastPlacedOrder();

                    if (!mounted || !dialogContext.mounted) return;
                    setState(() => isSubmitting = false);

                    if (errorMessage != null) {
                      Navigator.pop(dialogContext);
                      _showMessage(errorMessage);
                      return;
                    }

                    _pendingClientOrderId = null;
                    _pendingOrderFingerprint = null;
                    Navigator.pop(dialogContext);
                    final message = confirmedOrder == null
                        ? '${isBuy ? 'Buy' : 'Sell'} ${isLimit ? 'limit' : 'market'} order submitted'
                        : orderResultMessage(confirmedOrder);
                    _showMessage(message, order: confirmedOrder);
                  },
            child: AppText(isSubmitting ? 'Submitting...' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {TradingOrder? order}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText(message),
          action: order == null
              ? null
              : SnackBarAction(
                  label: 'View Order',
                  onPressed: () => _showOrderDetails(order),
                ),
        ),
      );
  }

  void _showOrderDetails(TradingOrder order) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final price = order.averageFillPrice ?? order.limitPrice ?? order.price;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: AppText(
                        '${order.symbol} Order',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppText(order.status.replaceAll('_', ' ')),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow('Side', order.isBuy ? 'BUY' : 'SELL'),
                _detailRow('Exchange', order.exchange),
                _detailRow(
                  'Order Type',
                  '${order.type == 'LIMIT' ? 'Limit Order' : 'Market Order'} • ${order.timeInForce}',
                ),
                _detailRow('Order Quantity', '${order.quantity}'),
                _detailRow('Filled Quantity', '${order.filledQuantity}'),
                _detailRow('Remaining Quantity', '${order.remainingQuantity}'),
                _detailRow(
                  order.isLimit ? 'Limit Price' : 'Execution Price',
                  price > 0 ? formatPrice(price) : '--',
                ),
                if (order.orderId?.isNotEmpty == true)
                  _detailRow('Order ID', order.orderId!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: AppText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _statPrice(double? value) => value == null ? '--' : formatPrice(value);

  double? get _yearHigh {
    final data = yearHistory?.data;
    if (data == null || data.isEmpty) return null;
    return data.map((point) => point.high).reduce((a, b) => a > b ? a : b);
  }

  double? get _yearLow {
    final data = yearHistory?.data;
    if (data == null || data.isEmpty) return null;
    return data.map((point) => point.low).reduce((a, b) => a < b ? a : b);
  }

  bool get _hasMarketRangeData =>
      (liveStock.high != null && liveStock.low != null) ||
      (_yearHigh != null && _yearLow != null);

  Widget _marketRangeCard() {
    final bid = liveStock.bid;
    final ask = liveStock.ask;
    final spread = bid != null && ask != null && ask >= bid ? ask - bid : null;
    final spreadPercent = spread != null && liveStock.price > 0
        ? spread / liveStock.price * 100
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Market Snapshot',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (liveStock.low != null && liveStock.high != null) ...[
              const SizedBox(height: 16),
              _priceRange(
                label: "Day's Range",
                low: liveStock.low!,
                high: liveStock.high!,
                price: liveStock.price,
              ),
            ],
            if (_yearLow != null && _yearHigh != null) ...[
              const SizedBox(height: 18),
              _priceRange(
                label: '52-Week Range',
                low: _yearLow!,
                high: _yearHigh!,
                price: liveStock.price,
              ),
            ],
            if (spread != null) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'Bid-Ask Spread',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  AppText(
                    '${formatPrice(spread)}'
                    '${spreadPercent == null ? '' : ' (${spreadPercent.toStringAsFixed(3)}%)'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceRange({
    required String label,
    required double low,
    required double high,
    required double price,
  }) {
    final span = high - low;
    final position = span <= 0 ? 0.5 : ((price - low) / span).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const markerSize = 12.0;
            final markerLeft =
                (constraints.maxWidth - markerSize) * position.toDouble();
            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: const BoxDecoration(
                        color: AppConfig.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: AppText(
                'Low ${formatPrice(low)}',
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ),
            AppText(
              'High ${formatPrice(high)}',
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AppPageScaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppConfig.textPrimaryColor,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(liveStock.symbol),
              AppText(
                liveStock.exchange,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: isWatched ? 'Remove from watchlist' : 'Add to watchlist',
              onPressed: watchlistLoading || watchlistSaving
                  ? null
                  : _toggleWatchlist,
              icon: watchlistSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConfig.primaryColor,
                      ),
                    )
                  : Icon(
                      isWatched ? Icons.star : Icons.star_border,
                      color: isWatched
                          ? const Color(0xFFFFB000)
                          : AppConfig.textPrimaryColor,
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _browseOnly ? null : _stickyTradeBar(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AppFadeIn(
                switchKey:
                    '${liveStock.symbol}:${liveStock.price}:${liveStock.quoteFresh}',
                child: StockQuoteHero(
                  stock: liveStock,
                  quotesConnected: socketConnected,
                ),
              ),
            ),
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.brandPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.brandPrimary,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Chart'),
                Tab(text: 'News'),
                Tab(text: 'Events'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _overviewTab(),
                  _chartTab(),
                  _newsTab(),
                  _eventsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_browseOnly) ...[
          const BrowseOnlyBanner(),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _marketStat('Best Bid', _statPrice(liveStock.bid)),
                    ),
                    Expanded(
                      child: _marketStat('Best Ask', _statPrice(liveStock.ask)),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _marketStat('Open', _statPrice(liveStock.open)),
                    ),
                    Expanded(
                      child: _marketStat(
                        'Prev. Close',
                        _statPrice(liveStock.previousClose),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _marketStat(
                        "Day's High",
                        _statPrice(liveStock.high),
                      ),
                    ),
                    Expanded(
                      child: _marketStat(
                        "Day's Low",
                        _statPrice(liveStock.low),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _marketStat(
                        'Volume',
                        _formatVolume(liveStock.volume),
                      ),
                    ),
                    Expanded(child: _marketStat('Symbol', liveStock.symbol)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_hasMarketRangeData) ...[
          const SizedBox(height: 12),
          _marketRangeCard(),
        ],
        const SizedBox(height: 18),
        if (!_browseOnly) ...[
          const AppText(
            'Place Order',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: true, label: AppText('Buy')),
              ButtonSegment<bool>(value: false, label: AppText('Sell')),
            ],
            selected: {isBuy},
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return AppConfig.textPrimaryColor;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (!states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return isBuy ? AppConfig.gainColor : AppConfig.lossColor;
              }),
            ),
            onSelectionChanged: (selection) => setState(() {
              isBuy = selection.first;
              _pendingClientOrderId = null;
              _pendingOrderFingerprint = null;
            }),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'MARKET',
                label: AppText('Market Order'),
              ),
              ButtonSegment<String>(
                value: 'LIMIT',
                label: AppText('Limit Order'),
              ),
            ],
            selected: {orderType},
            onSelectionChanged: (selection) {
              setState(() {
                orderType = selection.first;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
                if (orderType == 'LIMIT' &&
                    limitPriceController.text.trim().isEmpty) {
                  limitPriceController.text = liveStock.price.toStringAsFixed(
                    2,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          if (isLimit) ...[
            const SizedBox(height: 14),
            TextField(
              controller: limitPriceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Limit Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const AppText(
            'Validity',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['DAY', 'IOC', 'FOK']
                .map(
                  (value) => Tooltip(
                    message: switch (value) {
                      'IOC' => 'Immediate or Cancel',
                      'FOK' => 'Fill or Kill',
                      _ => 'Valid for the trading day',
                    },
                    child: ChoiceChip(
                      label: AppText(value),
                      selected: timeInForce == value,
                      selectedColor: AppConfig.primaryColor,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: timeInForce == value
                            ? Colors.white
                            : AppConfig.textPrimaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: timeInForce == value
                            ? AppConfig.primaryColor
                            : AppConfig.borderColor,
                      ),
                      onSelected: (_) => setState(() {
                        timeInForce = value;
                        _pendingClientOrderId = null;
                        _pendingOrderFingerprint = null;
                      }),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _orderPreviewCard(),
          const SizedBox(height: 8),
          AppText(
            'Use Buy / Sell below to review and submit your order.',
            style: TextStyle(
              color: AppConfig.textSecondaryColor.withValues(alpha: 0.9),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _chartTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        StockHistoryChart(
          symbol: liveStock.symbol,
          exchange: liveStock.exchange,
          latestPrice: liveStock.price,
          latestAt: liveStock.updatedAt,
          previousClose: liveStock.previousClose,
        ),
      ],
    );
  }

  Widget _newsTab() {
    if (newsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (newsFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'News could not be loaded. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadRelatedNews,
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (relatedNews.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'No verified headlines currently mention this stock.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: relatedNews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = relatedNews[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          onTap: () => showMarketNewsSheet(
            context: context,
            item: item,
            onOpen: _openNews,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              AppText(
                item.source,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventsTab() {
    if (yearHistoryFailed &&
        (yearHistory == null || yearHistory!.events.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppText(
                'Corporate events could not be loaded. Please try again.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadYearStats,
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final events = yearHistory?.events ?? const [];
    if (events.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: AppText(
            'No dividend or split events were returned for this range.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final event = events[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                event.type == 'SPLIT' ? 'Split' : 'Dividend',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              AppText(
                DateFormat('yyyy-MM-dd').format(event.date.toLocal()),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (event.label.isNotEmpty) ...[
                const SizedBox(height: 6),
                AppText(event.label),
              ],
              if (event.value > 0) ...[
                const SizedBox(height: 6),
                AppText(
                  event.value.toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stickyTradeBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
        AppSpacing.lg,
        AppSpacing.sm + 2,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppSpacing.buttonHeight + 4,
              child: FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setState(() => isBuy = true);
                        placeOrder();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.buy,
                  foregroundColor: AppColors.textInverse,
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: AppText(
                  'BUY',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: SizedBox(
              height: AppSpacing.buttonHeight + 4,
              child: FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setState(() => isBuy = false);
                        placeOrder();
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sell,
                  foregroundColor: AppColors.textInverse,
                  disabledBackgroundColor: AppColors.disabled,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderMd,
                  ),
                ),
                child: AppText(
                  'SELL',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderPreviewCard() {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final maxQuantity = isBuy ? maxBuyQuantity : availableSellQuantity;
    final deviation = limitDeviationPercent;
    final largeDeviation = deviation != null && deviation.abs() >= 5;
    final exceedsAvailable = maxQuantity != null && quantity > maxQuantity;
    final marketPriceLabel = isBuy ? 'best ask' : 'best bid';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: AppText(
                    'Order details',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                AppText(
                  selectedOrderPrice > 0 ? formatPrice(estimatedAmount) : '--',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _previewRow(
              'Indicative price',
              selectedOrderPrice > 0 ? formatPrice(selectedOrderPrice) : '--',
            ),
            _previewRow(
              'Price basis',
              isLimit ? 'Limit price' : 'Current $marketPriceLabel',
            ),
            if (isBuy && accountSnapshot != null)
              _previewRow(
                'Available buying power',
                formatPrice(accountSnapshot!.buyingPower),
              ),
            if (!isBuy && maxQuantity != null)
              _previewRow('Available to sell', '$maxQuantity shares'),
            if (maxQuantity != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        '${isBuy ? 'Maximum quantity' : 'Available quantity'}: '
                        '$maxQuantity',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    TextButton(
                      onPressed: maxQuantity <= 0
                          ? null
                          : () {
                              quantityController.text = '$maxQuantity';
                              setState(() {});
                            },
                      child: const AppText('Use max'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: AppText(
                'Final execution price and applicable charges are confirmed by the order result.',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ),
            if (largeDeviation || exceedsAvailable) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AppText(
                  exceedsAvailable
                      ? isBuy
                            ? 'Estimated amount exceeds available buying power.'
                            : 'Sell quantity exceeds the available holding.'
                      : 'Limit price is ${deviation!.abs().toStringAsFixed(2)}% '
                            '${deviation >= 0 ? 'above' : 'below'} the current price.',
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (!orderQuoteReady) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'A current market quote is required before submission.',
                      style: TextStyle(
                        color: AppConfig.lossColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: marketSocket.refreshSnapshot,
                    icon: const Icon(Icons.refresh, size: 17),
                    label: const AppText('Refresh'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: AppText(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          AppText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _marketStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 5),
        AppText(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(2)} Cr';
    }
    if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(2)} L';
    }
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)} K';
    }
    return '$volume';
  }
}

String orderResultMessage(TradingOrder order) {
  final filled = order.filledQuantity;
  final remaining = order.remainingQuantity;
  final fillPrice = order.averageFillPrice;
  final fillPriceText = fillPrice == null
      ? ''
      : ' • Avg. ${formatPrice(fillPrice)}';

  switch (order.status) {
    case 'FILLED':
      return 'Completed • Filled $filled/${order.quantity}$fillPriceText';
    case 'OPEN':
      return 'Order open • Filled $filled/${order.quantity} • Remaining $remaining';
    case 'PARTIALLY_FILLED':
      return 'Partially filled • Filled $filled/${order.quantity} • Remaining $remaining$fillPriceText';
    case 'CANCELLED':
      if (filled > 0) {
        return 'Partially filled • Filled $filled/${order.quantity} • Remaining $remaining cancelled$fillPriceText';
      }
      return 'Order cancelled • No shares filled';
    case 'REJECTED':
      final reason = order.rejectionReason?.trim();
      return reason == null || reason.isEmpty
          ? 'Order rejected'
          : 'Order rejected • $reason';
    case 'PENDING':
      return 'Order submitted';
    default:
      return 'Order ${order.status.toLowerCase().replaceAll('_', ' ')}';
  }
}
