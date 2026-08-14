import 'dart:async';

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/institutional_opportunity.dart';
import '../models/account_transaction.dart';
import '../models/ipo.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
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
    required this.indexQuotes,
    required this.onViewMarkets,
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
  final Map<String, (double, double)> indexQuotes;
  final VoidCallback onViewMarkets;

  @override
  State<TradingCenterPage> createState() => _TradingCenterPageState();
}

class _TradingCenterPageState extends State<TradingCenterPage>
    with WidgetsBindingObserver {
  final TradingService _tradingService = TradingService();
  final List<TradingOrder> _orders = <TradingOrder>[];
  final Map<String, PortfolioPosition> _positions =
      <String, PortfolioPosition>{};
  final List<AccountTransaction> _transactions = <AccountTransaction>[];
  TradingAccountSnapshot? _accountSnapshot;

  Timer? _refreshTimer;
  Future<void>? _refreshInFlight;
  int selectedTab = 0;

  final List<_TradingModule> tabs = const [
    _TradingModule('Overview', Icons.swap_horiz_rounded, Color(0xFF2563EB)),
    _TradingModule('Inst.', Icons.account_balance_outlined, Color(0xFF1D4ED8)),
    _TradingModule(
      'Holdings',
      Icons.account_balance_wallet_outlined,
      Color(0xFF059669),
    ),
    _TradingModule('Pending', Icons.schedule_rounded, Color(0xFFF97316)),
    _TradingModule('Orders', Icons.receipt_long_outlined, Color(0xFF7C3AED)),
    _TradingModule('OTC', Icons.handshake_outlined, Color(0xFF0D9488)),
    _TradingModule('IPO', Icons.campaign_outlined, Color(0xFFEF4444)),
    _TradingModule('History', Icons.history_rounded, Color(0xFFF59E0B)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncFromWidget();
    unawaited(_refreshTradingData(ensureAfterCurrent: true));
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
    final previousById = <String, TradingOrder>{
      for (final order in _orders)
        if (order.orderId?.isNotEmpty == true) order.orderId!: order,
    };
    final results = await Future.wait<Object?>([
      _tradingService
          .fetchOrders()
          .then<Object?>((value) => value)
          .catchError((_) => null),
      _tradingService
          .fetchAccountSnapshot()
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
        ..showSnackBar(SnackBar(content: Text(message)));
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
            const SizedBox(height: 10),
            SizedBox(
              height: 86,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final module = tabs[index];
                  final selected = selectedTab == index;

                  return _TradingModuleButton(
                    module: module,
                    selected: selected,
                    onTap: () {
                      setState(() => selectedTab = index);
                      if (index >= 2) {
                        unawaited(_refreshTradingData());
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                tabs.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selectedTab == index ? 22 : 7,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: selectedTab == index
                        ? tabs[index].color
                        : const Color(0xFFD7DCE5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedTab) {
      case 0:
        return TradeList(
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

class _TradingModuleButton extends StatelessWidget {
  const _TradingModuleButton({
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final _TradingModule module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFFBFCFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? module.color : const Color(0xFFE2E8F0),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? module.color.withValues(alpha: 0.16)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(module.icon, size: 24, color: module.color),
            const SizedBox(height: 7),
            Text(
              module.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? module.color : const Color(0xFF334155),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
