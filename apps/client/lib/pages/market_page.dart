import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_ui.dart';
import '../widgets/app_card.dart';
import '../widgets/account_metrics.dart';
import '../widgets/markets/market_index_ref.dart';
import '../widgets/home/home_dashboard.dart';
import '../widgets/home/home_dashboard_data.dart';
import '../theme/app_motion.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_menu.dart';
import '../models/async_data_state.dart';
import '../models/institutional_opportunity.dart';
import '../models/company_showcase.dart';
import '../models/ipo.dart';
import '../models/market_news_item.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../models/withdrawal_request.dart';
import '../services/app_content_service.dart';
import '../services/announcements_service.dart';
import '../services/featured_instruments_service.dart';
import '../services/auth_service.dart';
import '../widgets/app_settings_gates.dart';
import '../widgets/home_announcement_banner.dart';
import '../services/client_account_service.dart';
import '../services/device_biometrics.dart';
import '../services/ipo_service.dart';
import '../services/ipo_notice_store.dart';
import '../services/market_data_service.dart';
import '../services/market_socket_service.dart';
import '../services/trading_service.dart';
import '../utils/number_formatters.dart';
import '../utils/client_error_message.dart';
import '../utils/product_category.dart';
import 'account_security_page.dart';
import 'language_page.dart';
import '../l10n/app_language.dart';
import 'product_portfolio_page.dart';
import 'two_factor_page.dart';
import 'appearance_page.dart';
import '../theme/appearance_settings.dart';
import '../widgets/floating_support_button.dart';
import '../widgets/support_chat_launcher.dart';
import '../widgets/support_ui_metrics.dart';
import 'login_page.dart';
import 'index_detail_page.dart';
import 'markets_page.dart';
import 'market_news_page.dart';
import 'notifications_page.dart';
import 'account_settings_page.dart';
import 'account_content_page.dart';
import 'legal_page.dart';
import 'stock_detail_page.dart';
import 'stock_search_page.dart';
import 'deposit_page.dart';
import 'loan_page.dart';
import 'withdrawal_page.dart';
import 'trading_center_page.dart';

part 'market_page_account_section.dart';
part 'market_page_ipo_section.dart';
part 'market_page_market_actions.dart';
part 'market_page_account_actions.dart';
part 'market_page_market_view.dart';
part 'market_page_data_lifecycle.dart';
part 'market_page_portfolio_section.dart';

final marketSocket = MarketSocketService();
final marketDataService = MarketDataService();
final tradingService = TradingService();
final ipoService = IpoService();

class MarketHomePage extends StatefulWidget {
  const MarketHomePage({super.key});

  @override
  State<MarketHomePage> createState() => _MarketHomePageState();
}

class _MarketHomePageState extends State<MarketHomePage>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  int _previousSelectedIndex = 0;
  String _portfolioPeriod = '1D';
  AsyncDataState<_PortfolioHistoryData> _portfolioHistoryState =
      const AsyncDataState.initial();
  int _portfolioHistoryRequest = 0;
  bool _amountsHidden = false;

  List<double> get _portfolioSeries =>
      _portfolioHistoryState.data?.series ?? const <double>[];
  bool get _portfolioHistoryLoading => _portfolioHistoryState.isLoading;
  double? get _periodProfit => _portfolioHistoryState.data?.profit;
  String? get _historyFrom => _portfolioHistoryState.data?.from;
  String? get _historyError => _portfolioHistoryState.message;
  Map<String, dynamic> _profileData = {};
  DeviceBiometric? _biometricCapability;
  bool _biometricEnabled = false;
  bool _biometricBusy = false;
  bool _signingOut = false;
  bool isLoading = true;
  AsyncDataState<TradingAccountSnapshot> _accountSnapshotState =
      const AsyncDataState.loading();
  Future<void>? _accountRefreshInFlight;

  bool get _accountSnapshotLoaded => _accountSnapshotState.hasData;
  bool get _accountSnapshotFailed =>
      _accountSnapshotState.status == AsyncDataStatus.error ||
      _accountSnapshotState.requiresNotice;
  bool get _accountSnapshotRefreshing => _accountSnapshotState.isLoading;
  bool _ipoAllocationDialogOpen = false;
  final Set<String> _shownIpoAllotments = {};
  bool _iposFailed = false;
  bool _ipoApplicationsFailed = false;
  bool marketConnected = false;
  bool? marketOpen;
  int unreadNotificationCount = 0;
  String marketHours = '09:15 - 15:30 IST';
  Timer? _marketSessionTimer;
  Timer? _marketNewsTimer;
  Timer? _notificationTimer;
  Future<void>? _marketRefreshInFlight;

  double cashBalance = 0;
  double buyingPower = 0;
  double frozenBalance = 0;
  double realizedProfitLoss = 0;
  double? _authoritativeTotalAsset;
  double? _authoritativeUnrealizedPnl;

  double get availableBalance => math
      .max(0, math.min(buyingPower, cashBalance - frozenBalance))
      .toDouble();

  double nifty50Price = 0;
  double nifty50Change = 0;

  double sensexPrice = 0;
  double sensexChange = 0;

  double bankNiftyPrice = 0;
  double bankNiftyChange = 0;
  final Map<String, (double, double)> indexQuotes =
      <String, (double, double)>{};

  String accountName = 'Client';
  String accountPhone = '';
  String accountNumber = '';
  String kycStatus = 'UNKNOWN';
  Uint8List? profileAvatarBytes;

  final List<TradingOrder> orders = <TradingOrder>[];

  final List<WithdrawalRequest> withdrawalRequests = <WithdrawalRequest>[];

  final List<InstitutionalStock> institutionalStocks = <InstitutionalStock>[];

  final List<Ipo> ipos = <Ipo>[];

  final List<IpoApplication> ipoApplications = <IpoApplication>[];

  final Map<String, PortfolioPosition> positions =
      <String, PortfolioPosition>{};

  final List<StockQuote> stocks = <StockQuote>[];
  final List<StockQuote> _homeFeatured = <StockQuote>[];
  AnnouncementItem? _homeAnnouncement;
  final List<MarketNewsItem> marketNews = <MarketNewsItem>[];
  final List<CompanyShowcase> companyShowcases = <CompanyShowcase>[];
  final Map<String, List<double>> indexHistory = <String, List<double>>{};
  AppContentBundle _appContent = AppContentBundle.empty;
  bool _optionalUpdatePrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppContentService.instance.addListener(_onAppContentChanged);

    marketConnected = marketSocket.isConnected;
    unawaited(_reloadNews());
    marketSocket.addConnectionListener(_handleMarketConnection);
    _marketSessionTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshMarketSession(),
    );
    _marketNewsTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      final latest = await marketDataService.fetchMarketNews();
      if (!mounted || latest.isEmpty) return;
      setState(() {
        marketNews
          ..clear()
          ..addAll(latest);
      });
    });
    _notificationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshUnreadNotificationCount(),
    );

    marketSocket.onQuoteUpdate = (data) {
      final symbol = data['symbol']?.toString().trim().toUpperCase();

      final price = double.tryParse(data['price'].toString());

      final change = double.tryParse(data['change'].toString()) ?? 0;

      if (symbol == null || price == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        indexQuotes[symbol] = (price, change);
        if (symbol == 'NIFTY50') {
          nifty50Price = price;
          nifty50Change = change;
          return;
        }

        if (symbol == 'SENSEX') {
          sensexPrice = price;
          sensexChange = change;
          return;
        }

        if (symbol == 'BANKNIFTY') {
          bankNiftyPrice = price;
          bankNiftyChange = change;
          return;
        }

        final exchange = data['exchange']?.toString().trim().toUpperCase();
        final index = stocks.indexWhere(
          (stock) =>
              stock.symbol == symbol &&
              (exchange == null ||
                  exchange.isEmpty ||
                  stock.exchange == exchange),
        );

        if (index >= 0) {
          final updated = StockQuote.applyRealtime(stocks[index], data);
          if (updated != null) stocks[index] = updated;
        }
      });
    };

    _loadAppData();
    unawaited(_loadHomeIndexHistory());
    unawaited(_loadAppContent());
    unawaited(_loadHomeOpsContent());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppContentService.instance.removeListener(_onAppContentChanged);
    _marketSessionTimer?.cancel();
    _marketNewsTimer?.cancel();
    _notificationTimer?.cancel();
    marketSocket.removeConnectionListener(_handleMarketConnection);
    marketSocket.dispose();
    super.dispose();
  }

  void _onAppContentChanged() {
    if (!mounted) return;
    _updateState(() => _appContent = AppContentService.instance.current);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshMarketData());
      unawaited(_refreshAccountSnapshot());
      unawaited(_refreshUnreadNotificationCount());
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final navHeight = MediaQuery.textScalerOf(context).scale(1) > 1.2
        ? AppSpacing.navHeight + 8
        : AppSpacing.navHeight;
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      endDrawer: selectedIndex == 4 ? _profileSettingsDrawer() : null,
      endDrawerEnableOpenDragGesture: selectedIndex == 4,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AppPageTransition(
                  switchKey: selectedIndex,
                  forward: selectedIndex >= _previousSelectedIndex,
                  child: _selectedBody(),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: SupportUiMetrics.of(context).fabBottom,
            child: SafeArea(
              child: FloatingSupportButton(
                label: _appContent.text(
                  'support',
                  'fab_label',
                  fallback: 'Customer Service',
                ),
                onTap: () => unawaited(showSupportChatPanel(context)),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Color(0x120F2942),
                blurRadius: 14,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: navHeight,
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  indicatorShape: const CircleBorder(),
                  iconTheme: WidgetStateProperty.resolveWith((states) {
                    return IconThemeData(
                      size: 22,
                      color: states.contains(WidgetState.selected)
                          ? AppColors.navSelected
                          : AppColors.navUnselected,
                    );
                  }),
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    return AppTypography.caption.copyWith(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: states.contains(WidgetState.selected)
                          ? AppColors.navSelected
                          : AppColors.navUnselected,
                    );
                  }),
                ),
                child: NavigationBar(
                  height: navHeight,
                  elevation: 0,
                  backgroundColor: AppColors.surface,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(
                        Icons.home,
                        color: AppColors.navSelected,
                      ),
                      label: tr('Home'),
                      tooltip: tr('Home'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.bar_chart_outlined),
                      selectedIcon: const Icon(
                        Icons.bar_chart,
                        color: AppColors.navSelected,
                      ),
                      label: tr('Markets'),
                      tooltip: tr('Markets'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.swap_horiz_rounded),
                      selectedIcon: const Icon(
                        Icons.swap_horiz_rounded,
                        color: AppColors.navSelected,
                      ),
                      label: tr('Trade'),
                      tooltip: tr('Trade'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.pie_chart_outline_rounded),
                      selectedIcon: const Icon(
                        Icons.pie_chart_rounded,
                        color: AppColors.navSelected,
                      ),
                      label: tr('Portfolio'),
                      tooltip: tr('Portfolio'),
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.person_outline),
                      selectedIcon: const Icon(
                        Icons.person,
                        color: AppColors.navSelected,
                      ),
                      label: tr('Profile'),
                      tooltip: tr('Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickProfileAvatar() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final saved = await ClientAccountService().updateAvatar(
        base64Encode(bytes),
      );
      if (mounted) setState(() => profileAvatarBytes = base64Decode(saved));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(clientErrorMessage(error))));
      }
    }
  }

  void _applyAccountSnapshot(
    TradingAccountSnapshot snapshot, {
    bool positions = true,
  }) {
    cashBalance = snapshot.cashBalance;
    buyingPower = snapshot.buyingPower;
    frozenBalance = snapshot.frozenBalance;
    realizedProfitLoss = snapshot.realizedProfitLoss;
    _authoritativeTotalAsset = snapshot.totalAsset;
    _authoritativeUnrealizedPnl = snapshot.unrealizedPnl;
    if (!positions) return;
    this.positions
      ..clear()
      ..addEntries(
        snapshot.positions.map(
          (position) => MapEntry(
            _positionKey(position.exchange, position.symbol),
            position,
          ),
        ),
      );
  }

  void _updateState(VoidCallback update) => setState(update);

  String _positionKey(String exchange, String symbol) =>
      '${exchange.trim().toUpperCase()}:${symbol.trim().toUpperCase()}';

  StockQuote? _stockForOrNull(String symbol, {String? exchange}) {
    for (final stock in stocks) {
      if (stock.symbol == symbol &&
          (exchange == null || stock.exchange == exchange)) {
        return stock;
      }
    }

    return null;
  }
}

class _PortfolioHistoryData {
  const _PortfolioHistoryData({
    required this.series,
    required this.profit,
    required this.from,
  });

  final List<double> series;
  final double? profit;
  final String? from;
}
