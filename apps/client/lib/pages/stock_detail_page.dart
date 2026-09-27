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

part 'stock_detail_page_tabs_section.dart';
part 'stock_detail_page_data_section.dart';
part 'stock_detail_page_order_section.dart';

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
  void _setState(VoidCallback fn) => setState(fn);
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
                        semanticsLabel: 'Updating watchlist',
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
