import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_ui.dart';
import '../utils/number_formatters.dart';
import '../models/institutional_opportunity.dart';
import '../models/account_transaction.dart';
import '../models/ipo.dart';
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
import '../widgets/markets/instrument_browse.dart';
import '../widgets/market_status_card.dart';
import '../widgets/trading/pending_center_tab.dart';
import '../widgets/trading/trade_list.dart';
import '../widgets/app_feedback.dart';

class TradingCenterPage extends StatefulWidget {
  const TradingCenterPage({
    super.key,
    required this.stocks,
    required this.positions,
    required this.orders,
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
    this.onOpenOrderTicket,
    this.marketOpen,
    this.marketHours = '09:15 - 15:30 IST',
    this.quotesConnected,
    this.iposFailed = false,
    this.ipoApplicationsFailed = false,
    this.onRetryIpos,
  });

  final List<StockQuote> stocks;
  final List<Ipo> ipos;
  final List<IpoApplication> ipoApplications;
  final Map<String, PortfolioPosition> positions;
  final List<TradingOrder> orders;
  final List<InstitutionalStock> institutionalStocks;

  final ValueChanged<StockQuote> onTrade;
  final ValueChanged<Ipo> onApplyIpo;
  final VoidCallback onAlertsTap;
  final int notificationCount;
  final Map<String, (double, double)> indexQuotes;
  final VoidCallback onViewMarkets;
  final TradingService? tradingService;
  final void Function(StockQuote stock, {required bool isBuy})?
  onOpenOrderTicket;
  final bool? marketOpen;
  final String marketHours;
  final bool? quotesConnected;
  final bool iposFailed;
  final bool ipoApplicationsFailed;
  final Future<void> Function()? onRetryIpos;

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
        AppColors.brandPrimary,
      ),
      _TradingModule(
        label('tab.institutional', 'Institutional'),
        Icons.account_balance_outlined,
        AppColors.brandPrimaryPressed,
      ),
      _TradingModule(
        label('tab.holdings', 'Positions'),
        Icons.account_balance_wallet_outlined,
        AppColors.gain,
      ),
      _TradingModule(
        label('tab.pending', 'Pending'),
        Icons.schedule_rounded,
        AppColors.pending,
      ),
      _TradingModule(
        label('tab.order_book', 'Order Book'),
        Icons.receipt_long_outlined,
        AppColors.info,
      ),
      _TradingModule(
        label('tab.otc', 'OTC'),
        Icons.handshake_outlined,
        AppColors.gain,
      ),
      _TradingModule(
        label('tab.ipo', 'IPO'),
        Icons.campaign_outlined,
        AppColors.loss,
      ),
      _TradingModule(
        label('tab.history', 'History'),
        Icons.history_rounded,
        AppColors.warning,
      ),
      _TradingModule(
        label('tab.funds_ledger', 'Funds Ledger'),
        Icons.account_balance_wallet_outlined,
        AppColors.neutral,
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
    await AppContentService.instance.load(force: true);
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

  final Set<String> _cancellingOrderIds = <String>{};

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md + 2,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppText(
                      'Trade',
                      style: AppTypography.headline.copyWith(fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Markets',
                    onPressed: widget.onViewMarkets,
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    tooltip: tr('Funds Ledger'),
                    onPressed: () => _selectTab(8),
                    icon: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 22,
                      color: selectedTab == 8
                          ? AppColors.brandPrimary
                          : AppColors.textPrimary,
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
                          color: AppColors.textPrimary,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.loss,
                              shape: BoxShape.circle,
                            ),
                            child: AppText(
                              widget.notificationCount > 9
                                  ? '9+'
                                  : widget.notificationCount.toString(),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textInverse,
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
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm - 2,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: MarketStatusCard(
                isOpen: widget.marketOpen,
                hours: widget.marketHours,
                quotesConnected: widget.quotesConnected,
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm - 2,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              padding: const EdgeInsets.all(AppSpacing.lg + 2),
              decoration: AppUi.heroGradient(radius: AppRadius.lg),
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
                        const SizedBox(height: AppSpacing.md),
                        _balanceMetric(
                          'Buying Power',
                          _accountSnapshot?.buyingPower,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _balanceMetric(
                          'Frozen Funds',
                          _accountSnapshot?.frozenBalance,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _balanceMetric(
                          'Realized P&L',
                          _accountSnapshot?.realizedProfitLoss,
                          valueColor:
                              (_accountSnapshot?.realizedProfitLoss ?? 0) >= 0
                              ? AppColors.chartGain
                              : AppColors.loss,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _productTabs(),
            if (![1, 5, 6].contains(selectedTab)) _tradingShortcuts(),
            if (selectedTab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.buttonHeight,
                        child: FilledButton(
                          onPressed: () => _openTicket(isBuy: true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.buy,
                            foregroundColor: AppColors.textInverse,
                          ),
                          child: const AppText('Buy'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.buttonHeight,
                        child: FilledButton(
                          onPressed: () => _openTicket(isBuy: false),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.sell,
                            foregroundColor: AppColors.textInverse,
                          ),
                          child: const AppText('Sell'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (_ordersFailed || _accountFailed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        _ordersFailed && _accountFailed
                            ? 'Orders and balances could not be updated.'
                            : _ordersFailed
                            ? 'Orders could not be updated.'
                            : 'Balances and holdings could not be updated.',
                        style: AppTypography.bodySmall,
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

  void _openTicket({required bool isBuy}) {
    final tradable = widget.stocks
        .where((item) => !isBrowseOnlyInstrument(item))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: tradable.isEmpty
              ? const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: AppText(
                    'No supported stocks are available to trade. Unsupported products cannot be ordered.',
                  ),
                )
              : ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: AppText(
                        isBuy ? 'Buy' : 'Sell',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    for (final stock in tradable)
                      ListTile(
                        title: AppText(stock.symbol),
                        subtitle: AppText(
                          stock.name.isEmpty ? stock.exchange : stock.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          final open = widget.onOpenOrderTicket;
                          if (open != null) {
                            open(stock, isBuy: isBuy);
                          } else {
                            widget.onTrade(stock);
                          }
                        },
                      ),
                  ],
                ),
        );
      },
    );
  }

  Widget _productTabs() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
    child: Row(
      children: [
        for (final item in <(int, String)>[
          (
            0,
            AppContentService.instance.current.text(
              'trading',
              'tab.all',
              fallback: 'Overview',
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
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
                child: AppText(
                  item.$2,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _tradingShortcuts() {
    final items = <(int, String)>[
      (
        0,
        AppContentService.instance.current.text(
          'trading',
          'shortcut.overview',
          fallback: 'Overview',
        ),
      ),
      (
        2,
        AppContentService.instance.current.text(
          'trading',
          'tab.holdings',
          fallback: 'Positions',
        ),
      ),
      (
        4,
        AppContentService.instance.current.text(
          'trading',
          'shortcut.orders',
          fallback: 'Orders',
        ),
      ),
      (
        3,
        AppContentService.instance.current.text(
          'trading',
          'tab.pending',
          fallback: 'Pending',
        ),
      ),
      (
        7,
        AppContentService.instance.current.text(
          'trading',
          'tab.history',
          fallback: 'History',
        ),
      ),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final item = items[index];
          final selected = selectedTab == item.$1;
          return Semantics(
            selected: selected,
            child: Tooltip(
              message: tr(tabs[item.$1].label),
              child: ChoiceChip(
                label: AppText(item.$2),
                selected: selected,
                selectedColor: AppColors.brandPrimary,
                backgroundColor: AppColors.surface,
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: selected
                      ? AppColors.textInverse
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected ? AppColors.brandPrimary : AppColors.border,
                ),
                onSelected: (_) => _selectTab(item.$1),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _balanceMetric(String label, double? value, {Color? valueColor}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textInverse.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: AppText(
              value == null ? '--' : formatPrice(value),
              style: AppTypography.numericMedium.copyWith(
                color: valueColor ?? AppColors.textInverse,
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
      return const AppLoadingView(message: 'Loading trading data');
    }
    if ((missingOrders && _ordersFailed) ||
        (missingAccount && _accountFailed)) {
      return Center(
        child: AppText(
          AppContentService.instance.current.text(
            'trading',
            'state.data_unavailable',
            fallback: 'Trading data is temporarily unavailable.',
          ),
        ),
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
          onOpen: (stock) {
            StockQuote? match;
            for (final item in widget.stocks) {
              if (item.symbol.toUpperCase() == stock.symbol.toUpperCase() &&
                  item.exchange.toUpperCase() == stock.exchange.toUpperCase()) {
                match = item;
                break;
              }
            }
            final quote =
                match ??
                StockQuote(
                  stock.symbol,
                  stock.companyName,
                  stock.price > 0 ? stock.price : stock.marketPrice,
                  0,
                  0,
                  DateTime.now(),
                  exchange: stock.exchange,
                  category: 'INSTITUTIONAL',
                  quoteFresh: stock.price > 0 || stock.marketPrice > 0,
                );
            widget.onTrade(quote);
          },
        );
      case 2:
        return HoldingsTab(
          positions: _positions,
          stocks: widget.stocks,
          onSell: (stock, {required bool isBuy}) {
            widget.onOpenOrderTicket?.call(stock, isBuy: isBuy);
          },
        );
      case 3:
        return PendingCenterTab(
          activeOrders: _openAndPendingOrders,
          ipoApplications: widget.ipoApplications,
          applicationsFailed: widget.ipoApplicationsFailed,
          onRetryApplications: widget.onRetryIpos,
          onCancel: _cancelStandardOrder,
        );
      case 4:
        return OrdersTab(
          orders: _orders,
          onCancel: _cancelStandardOrder,
          loading: _transactionsLoading && _orders.isEmpty,
          failed: _ordersFailed,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
      case 5:
        return const OtcTab();
      case 6:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
          loadFailed: widget.iposFailed,
          onRetry: widget.onRetryIpos,
        );
      case 7:
        return HistoryTab(
          orders: _orders,
          onRefresh: () => _refreshTradingData(ensureAfterCurrent: true),
        );
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
