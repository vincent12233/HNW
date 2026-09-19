import '../widgets/app_page_scaffold.dart';
import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';
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
import '../utils/number_formatters.dart';
import '../widgets/app_card.dart';
import '../widgets/markets/browse_only_banner.dart';
import '../widgets/markets/instrument_browse.dart';
import '../widgets/markets/instrument_news.dart';
import '../widgets/markets/news_article_sheet.dart';
import '../widgets/markets/stock_quote_hero.dart';
import '../widgets/stock_history_chart.dart';
import '../widgets/trading/order_ticket.dart';
import '../widgets/trading/standard_order_details_sheet.dart';

class StockDetailPage extends StatefulWidget {
  const StockDetailPage({
    super.key,
    required this.stock,
    required this.onOrderPlaced,
    this.initialIsBuy = true,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
    this.tradingService,
  });

  final StockQuote stock;
  final Future<String?> Function(TradingOrder) onOrderPlaced;
  final bool initialIsBuy;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;
  final TradingService? tradingService;

  @visibleForTesting
  static TradingOrder? debugNextConfirmedOrder;

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  final quantityController = TextEditingController(text: '1');
  final limitPriceController = TextEditingController();
  final marketSocket = MarketSocketService();
  final watchlistService = WatchlistService();

  late final TradingService _tradingService;
  late StockQuote liveStock;
  late bool isBuy;
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

  String? get quantityError {
    final raw = quantityController.text.trim();
    if (raw.isEmpty) return null;
    final quantity = int.tryParse(raw);
    if (quantity == null || quantity <= 0) {
      return 'Enter a quantity greater than 0';
    }
    return null;
  }

  String? get priceError {
    if (!isLimit) return null;
    final raw = limitPriceController.text.trim();
    if (raw.isEmpty) return null;
    final price = double.tryParse(raw);
    if (price == null || price <= 0) {
      return 'Enter a limit price greater than 0';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    liveStock = widget.stock;
    isBuy = widget.initialIsBuy;
    _tradingService = widget.tradingService ?? TradingService();
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
      final snapshot = await _tradingService.fetchAccountSnapshot();
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

  Future<void> placeOrder() async {
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

    final quoteDelayed =
        !socketConnected ||
        !liveStock.quoteFresh ||
        DateTime.now().difference(liveStock.updatedAt) >
            const Duration(minutes: 2);
    final riskNotice = [
      if (widget.marketOpen == false)
        'The exchange session is closed. Confirm stays disabled until the market is open. The server still verifies session state.',
      if (quoteDelayed)
        'Market price may be delayed. Review the order price before confirming.',
    ].join('\n\n');

    String? successMessage;
    TradingOrder? confirmedOrder;

    await showOrderConfirmDialog(
      context: context,
      stock: liveStock,
      isBuy: isBuy,
      orderType: orderType,
      timeInForce: timeInForce,
      quantity: quantity,
      estimatedAmount: estimatedAmount,
      limitPrice: isLimit ? limitPrice : null,
      marketOpen: widget.marketOpen,
      marketHours: widget.marketHours,
      riskNotice: riskNotice.isEmpty ? null : riskNotice,
      onConfirm: () async {
        if (isSubmitting) {
          return 'Order is already being submitted.';
        }
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
        _pendingClientOrderId ??= TradingService.createClientOrderId(
          exchange: draft.exchange,
          symbol: draft.symbol,
        );
        final order = draft.withClientOrderId(_pendingClientOrderId!);

        TradingService.clearLastPlacedOrder();
        final String? errorMessage;
        try {
          errorMessage = await widget.onOrderPlaced(order);
        } catch (_) {
          if (mounted) setState(() => isSubmitting = false);
          return 'Order placement failed';
        }
        confirmedOrder =
            TradingService.takeLastPlacedOrder() ??
            StockDetailPage.debugNextConfirmedOrder;
        StockDetailPage.debugNextConfirmedOrder = null;

        if (!mounted) return errorMessage;
        setState(() => isSubmitting = false);

        if (errorMessage != null) {
          return errorMessage;
        }

        _pendingClientOrderId = null;
        _pendingOrderFingerprint = null;
        successMessage = confirmedOrder == null
            ? '${isBuy ? 'Buy' : 'Sell'} ${isLimit ? 'limit' : 'market'} order submitted'
            : orderResultMessage(confirmedOrder!);
        return null;
      },
    );

    if (successMessage != null) {
      _showMessage(successMessage!, order: confirmedOrder);
    }
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
    showStandardOrderDetails(context, order: order);
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final compact = keyboard > 80 || constraints.maxHeight < 520;
            final tabHeight = (constraints.maxHeight - (compact ? 160 : 280))
                .clamp(220.0, 900.0);
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    if (!compact)
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
                    SizedBox(
                      height: tabHeight,
                      child: TabBarView(
                        children: [
                          _overviewTab(),
                          _chartTab(),
                          _newsTab(),
                          _eventsTab(),
                        ],
                      ),
                    ),
                    if (!_browseOnly)
                      OrderTicketBar(
                        submitting: isSubmitting,
                        onBuy: () {
                          setState(() => isBuy = true);
                          unawaited(placeOrder());
                        },
                        onSell: () {
                          setState(() => isBuy = false);
                          unawaited(placeOrder());
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _overviewTab() {
    return SingleChildScrollView(
      key: const Key('stock-overview'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        child: _marketStat(
                          'Best Bid',
                          _statPrice(liveStock.bid),
                        ),
                      ),
                      Expanded(
                        child: _marketStat(
                          'Best Ask',
                          _statPrice(liveStock.ask),
                        ),
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
            OrderTicketPanel(
              stock: liveStock,
              isBuy: isBuy,
              orderType: orderType,
              timeInForce: timeInForce,
              quantityController: quantityController,
              limitPriceController: limitPriceController,
              account: accountSnapshot,
              marketOpen: widget.marketOpen,
              marketHours: widget.marketHours,
              quotesConnected: widget.quotesConnected ?? socketConnected,
              quantityError: quantityError,
              priceError: priceError,
              onBuyChanged: (value) => setState(() {
                isBuy = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
              }),
              onOrderTypeChanged: (value) => setState(() {
                orderType = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
                if (orderType == 'LIMIT' &&
                    limitPriceController.text.trim().isEmpty) {
                  limitPriceController.text = liveStock.price.toStringAsFixed(
                    2,
                  );
                }
              }),
              onTimeInForceChanged: (value) => setState(() {
                timeInForce = value;
                _pendingClientOrderId = null;
                _pendingOrderFingerprint = null;
              }),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            OrderEstimateCard(
              stock: liveStock,
              isBuy: isBuy,
              isLimit: isLimit,
              quantity: int.tryParse(quantityController.text) ?? 0,
              selectedPrice: selectedOrderPrice,
              estimatedAmount: estimatedAmount,
              account: accountSnapshot,
              maxQuantity: isBuy ? maxBuyQuantity : availableSellQuantity,
              deviationPercent: limitDeviationPercent,
              quoteReady: orderQuoteReady,
              onUseMax: () {
                final maxQuantity = isBuy
                    ? maxBuyQuantity
                    : availableSellQuantity;
                if (maxQuantity == null || maxQuantity <= 0) return;
                quantityController.text = '$maxQuantity';
                setState(() {});
              },
            ),
            const SizedBox(height: 8),
            AppText(
              'Use Buy / Sell below to review the order. Confirm is required before it is sent.',
              style: TextStyle(
                color: AppConfig.textSecondaryColor.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
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
