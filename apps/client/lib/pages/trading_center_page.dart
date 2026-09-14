import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../utils/number_formatters.dart';
import '../models/institutional_opportunity.dart';
import '../models/account_transaction.dart';
import '../models/ipo.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../services/app_content_service.dart';
import '../services/trading_service.dart';
import '../widgets/trading/history_tab.dart';
import '../widgets/trading/funds_tab.dart';

import '../widgets/trading/holdings_tab.dart';
import '../widgets/trading/institutional_tab.dart';
import '../widgets/trading/ipo_tab.dart';
import '../widgets/trading/orders_tab.dart';
import '../widgets/trading/otc_tab.dart';
import '../widgets/trading/pending_center_tab.dart';
import '../widgets/trading/trade_list.dart';

class TradingCenterPage extends StatefulWidget {
  const TradingCenterPage({
    super.key,
    required this.stocks,
    required this.positions,
    required this.orders,
    required this.pendingOrders,
    required this.institutionalStocks,
    required this.ipos,
    required this.ipoApplications,
    required this.onTrade,
    required this.onApplyIpo,
    required this.onAlertsTap,
    required this.notificationCount,
    required this.indexQuotes,
    required this.onViewMarkets,
    this.tradingService,
  });

  final List<StockQuote> stocks;
  final List<Ipo> ipos;
  final List<IpoApplication> ipoApplications;
  final Map<String, PortfolioPosition> positions;
  final List<TradingOrder> orders;
  final List<PendingOrder> pendingOrders;
  final List<InstitutionalStock> institutionalStocks;

  final ValueChanged<StockQuote> onTrade;
  final ValueChanged<Ipo> onApplyIpo;
  final VoidCallback onAlertsTap;
  final int notificationCount;
  final Map<String, (double, double)> indexQuotes;
  final VoidCallback onViewMarkets;
  final TradingService? tradingService;

  @override
  State<TradingCenterPage> createState() => _TradingCenterPageState();
}

class _TradingCenterPageState extends State<TradingCenterPage>
    with WidgetsBindingObserver {
  late final TradingService _tradingService =
      widget.tradingService ?? TradingService();
  bool _ordersFailed = false;
  bool _accountFailed = false;
  final List<TradingOrder> _orders = <TradingOrder>[];
  final Map<String, PortfolioPosition> _positions =
      <String, PortfolioPosition>{};
  final List<AccountTransaction> _transactions = <AccountTransaction>[];
  bool _transactionsLoading = true;
  bool _transactionsFailed = false;
  TradingAccountSnapshot? _accountSnapshot;

  Timer? _refreshTimer;
  Future<void>? _refreshInFlight;
  int selectedTab = 0;

  List<_TradingModule> get tabs {
    final c = AppContentService.instance.current;
    String label(String key, String fallback) =>
        c.text('trading', key, fallback: fallback);
    return [
      _TradingModule(
        label('tab.trades', 'Trades'),
        Icons.swap_horiz_rounded,
        const Color(0xFF2563EB),
      ),
      _TradingModule(
        label('tab.institutional', 'Institutional'),
        Icons.account_balance_outlined,
        const Color(0xFF1D4ED8),
      ),
      _TradingModule(
        label('tab.holdings', 'Holdings'),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF059669),
      ),
      _TradingModule(
        label('tab.pending', 'Pending'),
        Icons.schedule_rounded,
        const Color(0xFFF97316),
      ),
      _TradingModule(
        label('tab.order_book', 'Order Book'),
        Icons.receipt_long_outlined,
        const Color(0xFF7C3AED),
      ),
      _TradingModule(
        label('tab.otc', 'OTC'),
        Icons.handshake_outlined,
        const Color(0xFF0D9488),
      ),
      _TradingModule(
        label('tab.ipo', 'IPO'),
        Icons.campaign_outlined,
        const Color(0xFFEF4444),
      ),
      _TradingModule(
        label('tab.history', 'History'),
        Icons.history_rounded,
        const Color(0xFFF59E0B),
      ),
      _TradingModule(
        label('tab.funds_ledger', 'Funds Ledger'),
        Icons.account_balance_wallet_outlined,
        const Color(0xFF64748B),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppContentService.instance.addListener(_onAppContentChanged);
    unawaited(AppContentService.instance.load());
    _syncFromWidget();
    unawaited(_refreshTradingData(ensureAfterCurrent: true));
  }

  void _onAppContentChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TradingCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders ||
        oldWidget.positions != widget.positions) {
      _syncFromWidget();
    }
  }

  @override
  void dispose() {
    AppContentService.instance.removeListener(_onAppContentChanged);
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshTradingData(ensureAfterCurrent: true));
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  void _syncFromWidget() {
    _orders
      ..clear()
      ..addAll(widget.orders);
    _positions
      ..clear()
      ..addAll(widget.positions);
  }

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
    setState(() => _transactionsLoading = true);
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

    setState(() {
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

    try {
      await _tradingService.cancelOrder(orderId);
      await _refreshTradingData(ensureAfterCurrent: true);
      return null;
    } on TradingException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  List<TradingOrder> get _activeOrders => _orders
      .where(
        (order) => order.status == 'OPEN' || order.status == 'PARTIALLY_FILLED',
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'Trade',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Markets',
                    onPressed: widget.onViewMarkets,
                    icon: const Icon(Icons.search_rounded, size: 22),
                  ),
                  IconButton(
                    tooltip: tr('Funds Ledger'),
                    onPressed: () => _selectTab(8),
                    icon: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 22,
                      color: selectedTab == 8 ? AppConfig.primaryColor : null,
                    ),
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: widget.onAlertsTap,
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 22,
                        ),
                      ),
                      if (widget.notificationCount > 0)
                        Positioned(
                          right: 6,
                          top: 4,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 17,
                              minHeight: 17,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF233C),
                              shape: BoxShape.circle,
                            ),
                            child: AppText(
                              widget.notificationCount > 9
                                  ? '9+'
                                  : widget.notificationCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
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
            Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    AppConfig.primaryDarkColor,
                    AppConfig.primaryGradientEnd,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _balanceMetric(
                          'Available Funds',
                          _accountSnapshot?.availableBalance,
                        ),
                        const SizedBox(height: 12),
                        _balanceMetric(
                          'Buying Power',
                          _accountSnapshot?.buyingPower,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _balanceMetric(
                          'Realized P&L',
                          _accountSnapshot?.realizedProfitLoss,
                          valueColor:
                              (_accountSnapshot?.realizedProfitLoss ?? 0) >= 0
                              ? const Color(0xff70e0ba)
                              : const Color(0xffffa6b1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _productTabs(),
            if (![1, 5, 6].contains(selectedTab)) _tradingShortcuts(),
            const SizedBox(height: 8),
            if (_ordersFailed || _accountFailed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        _ordersFailed && _accountFailed
                            ? 'Orders and balances could not be updated.'
                            : _ordersFailed
                            ? 'Orders could not be updated.'
                            : 'Balances and holdings could not be updated.',
                      ),
                    ),
                    TextButton(
                      onPressed: _transactionsLoading
                          ? null
                          : () => _refreshTradingData(),
                      child: const AppText('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => selectedTab = index);
    if (index >= 2) unawaited(_refreshTradingData());
  }

  Widget _productTabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final item in <(int, String)>[
          (
            0,
            AppContentService.instance.current.text(
              'trading',
              'tab.all',
              fallback: 'All',
            ),
          ),
          (
            1,
            AppContentService.instance.current.text(
              'trading',
              'tab.ins_stock',
              fallback: 'Ins. Stock',
            ),
          ),
          (
            5,
            AppContentService.instance.current.text(
              'trading',
              'tab.otc',
              fallback: 'OTC',
            ),
          ),
          (
            6,
            AppContentService.instance.current.text(
              'trading',
              'tab.ipo',
              fallback: 'IPO',
            ),
          ),
        ])
          Expanded(
            child: Semantics(
              selected:
                  selectedTab == item.$1 ||
                  (item.$1 == 0 && [2, 3, 4, 7].contains(selectedTab)),
              child: TextButton(
                onPressed: () => _selectTab(item.$1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  minimumSize: const Size(0, 48),
                  foregroundColor:
                      selectedTab == item.$1 ||
                          (item.$1 == 0 && [2, 3, 4, 7].contains(selectedTab))
                      ? AppConfig.primaryColor
                      : AppConfig.textSecondaryColor,
                ),
                child: AppText(
                  item.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _tradingShortcuts() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(
      children: [
        for (final item in <(int, String, IconData)>[
          (
            4,
            AppContentService.instance.current.text(
              'trading',
              'shortcut.orders',
              fallback: 'Orders',
            ),
            Icons.receipt_long_outlined,
          ),
          (
            3,
            AppContentService.instance.current.text(
              'trading',
              'tab.pending',
              fallback: 'Pending',
            ),
            Icons.pending_actions_outlined,
          ),
          (
            2,
            AppContentService.instance.current.text(
              'trading',
              'tab.holdings',
              fallback: 'Holdings',
            ),
            Icons.account_balance_outlined,
          ),
          (
            7,
            AppContentService.instance.current.text(
              'trading',
              'tab.history',
              fallback: 'History',
            ),
            Icons.history,
          ),
        ])
          Expanded(
            child: Semantics(
              selected: selectedTab == item.$1,
              child: Tooltip(
                message: tr(tabs[item.$1].label),
                child: InkWell(
                  onTap: () => _selectTab(item.$1),
                  child: SizedBox(
                    height: MediaQuery.textScalerOf(context).scale(1) > 1.2
                        ? 68
                        : 64,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.$3,
                          size: 21,
                          color: selectedTab == item.$1
                              ? AppConfig.primaryColor
                              : const Color(0xFF0F9D92),
                        ),
                        const SizedBox(height: 6),
                        AppText(
                          item.$2,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: selectedTab == item.$1
                                ? AppConfig.primaryColor
                                : AppConfig.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _balanceMetric(String label, double? value, {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AppText(
              value == null ? '--' : formatPrice(value),
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
  Widget _buildContent() {
    final missingOrders = _orders.isEmpty && [0, 4, 7].contains(selectedTab);
    final missingAccount = _positions.isEmpty && [0, 2].contains(selectedTab);
    if ((missingOrders || missingAccount) && _transactionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((missingOrders && _ordersFailed) ||
        (missingAccount && _accountFailed)) {
      return const Center(
        child: AppText('Trading data is temporarily unavailable.'),
      );
    }
    switch (selectedTab) {
      case 0:
        return TradeList(
          orders: _orders,
          onViewOrders: () => setState(() => selectedTab = 4),
          onCancel: _cancelStandardOrder,
          stocks: widget.stocks,
          positions: _positions,
          account: _accountSnapshot,
          onTrade: widget.onTrade,
          indexQuotes: widget.indexQuotes,
          onViewMarkets: widget.onViewMarkets,
        );
      case 1:
        return InstitutionalTab(
          stocks: widget.institutionalStocks,
          marketStocks: widget.stocks,
        );
      case 2:
        return HoldingsTab(
          positions: _positions,
          stocks: widget.stocks,
          onStockTap: widget.onTrade,
        );
      case 3:
        return PendingCenterTab(
          activeOrders: _activeOrders,
          ipoApplications: widget.ipoApplications,
          onOrderCancelled: () =>
              unawaited(_refreshTradingData(ensureAfterCurrent: true)),
        );
      case 4:
        return OrdersTab(orders: _orders, onCancel: _cancelStandardOrder);
      case 5:
        return const OtcTab();
      case 6:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
        );
      case 7:
        return HistoryTab(orders: _orders);
      case 8:
        return FundsTab(
          transactions: _transactions,
          loading: _transactionsLoading,
          loadFailed: _transactionsFailed,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _TradingModule {
  const _TradingModule(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}



