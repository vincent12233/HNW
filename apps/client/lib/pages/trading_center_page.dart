import 'dart:async';

import 'package:flutter/material.dart';

import '../models/institutional_opportunity.dart';
import '../models/ipo.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../services/trading_service.dart';
import '../widgets/trading/history_tab.dart';
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

  @override
  State<TradingCenterPage> createState() => _TradingCenterPageState();
}

class _TradingCenterPageState extends State<TradingCenterPage> {
  final TradingService _tradingService = TradingService();
  final List<TradingOrder> _orders = <TradingOrder>[];
  final Map<String, PortfolioPosition> _positions = <String, PortfolioPosition>{};

  Timer? _refreshTimer;
  bool _refreshing = false;
  int selectedTab = 0;

  final List<_TradingModule> tabs = const [
    _TradingModule('Trades', Icons.swap_horiz_rounded, Color(0xFF2563EB)),
    _TradingModule('Inst.', Icons.account_balance_outlined, Color(0xFF1D4ED8)),
    _TradingModule('Holdings', Icons.account_balance_wallet_outlined, Color(0xFF059669)),
    _TradingModule('Pending', Icons.schedule_rounded, Color(0xFFF97316)),
    _TradingModule('Orders', Icons.receipt_long_outlined, Color(0xFF7C3AED)),
    _TradingModule('IPO', Icons.campaign_outlined, Color(0xFFEF4444)),
    _TradingModule('OTC', Icons.handshake_outlined, Color(0xFF0D9488)),
    _TradingModule('History', Icons.history_rounded, Color(0xFFF59E0B)),
  ];

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
    unawaited(_refreshTradingData());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshTradingData()),
    );
  }

  @override
  void didUpdateWidget(covariant TradingCenterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders || oldWidget.positions != widget.positions) {
      _syncFromWidget();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _syncFromWidget() {
    _orders
      ..clear()
      ..addAll(widget.orders);
    _positions
      ..clear()
      ..addAll(widget.positions);
  }

  Future<void> _refreshTradingData() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final results = await Future.wait<dynamic>([
        _tradingService.fetchOrders(),
        _tradingService.fetchAccountSnapshot(),
      ]);
      if (!mounted) return;

      final latestOrders = results[0] as List<TradingOrder>;
      final snapshot = results[1] as TradingAccountSnapshot?;

      setState(() {
        _orders
          ..clear()
          ..addAll(latestOrders);
        if (snapshot != null) {
          _positions
            ..clear()
            ..addEntries(
              snapshot.positions.map((position) => MapEntry(position.symbol, position)),
            );
        }
      });
    } finally {
      _refreshing = false;
    }
  }

  Future<String?> _cancelStandardOrder(TradingOrder order) async {
    final orderId = order.orderId;
    if (orderId == null || orderId.isEmpty) {
      return 'Order reference is unavailable';
    }

    try {
      await _tradingService.cancelOrder(orderId);
      await _refreshTradingData();
      return null;
    } on TradingException catch (error) {
      return error.message;
    } catch (error) {
      return error.toString();
    }
  }

  List<TradingOrder> get _activeOrders => _orders
      .where((order) => order.status == 'OPEN' || order.status == 'PARTIALLY_FILLED')
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Trading Center',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Alerts',
                    onPressed: widget.onAlertsTap,
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                      if (index == 2 || index == 3 || index == 4 || index == 7) {
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
                    color: selectedTab == index ? tabs[index].color : const Color(0xFFD7DCE5),
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
        return TradeList(stocks: widget.stocks, onTrade: widget.onTrade);
      case 1:
        return InstitutionalTab(stocks: widget.institutionalStocks);
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
          onOrderCancelled: () => unawaited(_refreshTradingData()),
        );
      case 4:
        return OrdersTab(orders: _orders, onCancel: _cancelStandardOrder);
      case 5:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
        );
      case 6:
        return OtcTab(opportunities: widget.institutionalStocks);
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
