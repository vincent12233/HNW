import '../l10n/app_language.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
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
import '../widgets/market_status_card.dart';
import '../widgets/trading/pending_center_tab.dart';
import '../widgets/trading/trade_list.dart';
import '../widgets/app_feedback.dart';

part 'trading_center_page_action_section.dart';
part 'trading_center_page_tabs_section.dart';
part 'trading_center_page_content_section.dart';
part 'trading_center_page_data_lifecycle.dart';

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
  void _setState(VoidCallback fn) => setState(fn);
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
  final Set<String> _cancellingOrderIds = <String>{};
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
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
                        tooltip: tr('Markets'),
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
                            tooltip: tr('Notifications'),
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
                  padding: const EdgeInsets.all(AppSpacing.md + 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.brandPrimary,
                        AppColors.brandGradientEnd,
                      ],
                    ),
                    borderRadius: AppRadius.borderMd,
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
                              'Realized P&L',
                              _accountSnapshot?.realizedProfitLoss,
                              valueColor:
                                  (_accountSnapshot?.realizedProfitLoss ?? 0) >=
                                      0
                                  ? AppColors.chartGain
                                  : AppColors.loss,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _balanceMetric(
                              'Unrealized P&L',
                              _accountSnapshot?.unrealizedPnl,
                              valueColor:
                                  (_accountSnapshot?.unrealizedPnl ?? 0) >= 0
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
                const SizedBox(height: AppSpacing.sm),
                if (_ordersFailed || _accountFailed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
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
                          child: AppText(
                            AppContentService.instance.current.text(
                              'trading',
                              'action.retry',
                              fallback: 'Retry',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => selectedTab = index);
    if (index >= 2) unawaited(_refreshTradingData());
  }

}

class _TradingModule {
  const _TradingModule(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}
