import 'dart:async';
import 'loan_page.dart';
import '../widgets/membership_tier_badge.dart';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/app_ui.dart';
import '../widgets/home/home_action_button.dart';
import '../widgets/home/mini_line_chart_painter.dart';
import '../models/institutional_opportunity.dart';
import '../models/company_showcase.dart';
import '../models/ipo.dart';
import '../models/market_news_item.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../models/withdrawal_request.dart';
import '../services/app_content_service.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
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
import '../widgets/market_header.dart';
import '../widgets/market_status_card.dart';
import '../widgets/stock_logo.dart';
import '../widgets/floating_support_button.dart';
import '../widgets/support_chat_launcher.dart';
import '../widgets/support_ui_metrics.dart';
import 'login_page.dart';
import 'markets_page.dart';
import 'market_news_page.dart';
import 'notifications_page.dart';
import 'account_settings_page.dart';
import 'account_content_page.dart';
import 'legal_page.dart';
import 'stock_detail_page.dart';
import 'stock_search_page.dart';
import 'deposit_page.dart';
import 'trading_center_page.dart';

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
  static const double _minimumWithdrawalAmount = 100;
  int selectedIndex = 0;
  String _portfolioPeriod = '1D';
  List<double> _portfolioSeries = const <double>[];
  bool _portfolioHistoryLoading = false;
  int _portfolioHistoryRequest = 0;
  bool _amountsHidden = false;
  double? _periodProfit;
  String? _historyFrom;
  String? _historyError;
  Map<String, dynamic> _profileData = {};
  bool isLoading = true;
  bool _ipoAllocationDialogOpen = false;
  final Set<String> _shownIpoAllotments = {};
  bool _withdrawalSubmitting = false;
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
  String kycStatus = 'NOT_SUBMITTED';
  Uint8List? profileAvatarBytes;

  final List<TradingOrder> orders = <TradingOrder>[];

  final List<WithdrawalRequest> withdrawalRequests = <WithdrawalRequest>[];

  final List<InstitutionalStock> institutionalStocks = <InstitutionalStock>[];

  final List<Ipo> ipos = <Ipo>[];

  final List<IpoApplication> ipoApplications = <IpoApplication>[];

  final Map<String, PortfolioPosition> positions =
      <String, PortfolioPosition>{};

  final List<StockQuote> stocks = <StockQuote>[];
  final List<MarketNewsItem> marketNews = <MarketNewsItem>[];
  final List<CompanyShowcase> companyShowcases = <CompanyShowcase>[];
  final Map<String, List<double>> stockHistory = <String, List<double>>{};
  final Map<String, List<double>> indexHistory = <String, List<double>>{};
  AppContentBundle _appContent = AppContentBundle.empty;

  Future<void> _applyIpo(Ipo ipo) async {
    final applicationCount = ipoApplications
        .where((application) => application.ipoId == ipo.id)
        .length;

    if (applicationCount >= 5) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Maximum of 5 applications allowed for this IPO'),
        ),
      );

      return;
    }

    try {
      await ipoService.apply(ipo.id);
      final remoteApplications = await ipoService.fetchMyApplications();

      if (!mounted) return;

      setState(() {
        ipoApplications
          ..clear()
          ..addAll(remoteApplications);
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '${ipo.companyName} application ${applicationCount + 1} of 5 submitted',
          ),
        ),
      );
    } on IpoException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error.message)));
    }
  }

  void _showPendingIpoAllocationIfNeeded() {
    if (!mounted || _ipoAllocationDialogOpen) {
      return;
    }

    IpoApplication? pendingApplication;

    for (final application in ipoApplications) {
      if (application.hasAllocation &&
          !_shownIpoAllotments.contains(application.id)) {
        pendingApplication = application;
        break;
      }
    }

    if (pendingApplication == null) {
      return;
    }

    _showIpoAllocationDialog(pendingApplication);
  }

  Future<void> _showIpoAllocationDialog(IpoApplication application) async {
    if (!mounted || _ipoAllocationDialogOpen) {
      return;
    }

    if (!application.hasAllocation) {
      return;
    }

    _ipoAllocationDialogOpen = true;
    _shownIpoAllotments.add(application.id);
    final noticeStore = IpoNoticeStore();
    bool previouslyConfirmed = false;
    try {
      previouslyConfirmed = await noticeStore.isConfirmed(application.id);
    } catch (_) {
      // Storage failure must not prevent the customer seeing an allotment.
    }
    if (!mounted || previouslyConfirmed) {
      _ipoAllocationDialogOpen = false;
      if (mounted) _showPendingIpoAllocationIfNeeded();
      return;
    }
    final needsFunds = application.remainingAmount > 0;

    final totalSubscriptionAmount =
        application.allocatedQuantity * application.subscriptionPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE59A), Color(0xFFFFBF36)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 68,
                  color: Color(0xFFB77700),
                ),
              ),
              const SizedBox(height: 20),
              const AppText(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB77700),
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 10),
              const AppText(
                'Your IPO application has been successfully allotted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  application.companyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  application.symbol,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: needsFunds
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppText(
                    needsFunds
                        ? 'You have received an IPO allotment. '
                              'Please add the required funds to complete '
                              'your subscription. No further action is needed after funds arrive.'
                        : 'Your subscription is complete. Your allocated shares have been added to your holdings.',
                    style: TextStyle(
                      height: 1.4,
                      color: needsFunds
                          ? const Color(0xFFB42318)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ipoDialogValue(
                  'Allocated Quantity',
                  '${application.allocatedQuantity} Shares',
                ),
                const Divider(height: 24),
                _ipoDialogValue(
                  'Subscription Price',
                  formatPrice(application.subscriptionPrice),
                ),
                const Divider(height: 24),
                _ipoDialogValue(
                  'Total Subscription Amount',
                  formatPrice(totalSubscriptionAmount),
                ),
                if (needsFunds) ...[
                  const Divider(height: 24),
                  _ipoDialogValue(
                    'Additional Funds Required',
                    formatPrice(application.remainingAmount),
                    valueColor: AppConfig.lossColor,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await noticeStore.confirm(application.id);
      } catch (_) {
        // Session-level deduplication still applies if persistence is unavailable.
      }
    }
    _ipoAllocationDialogOpen = false;
    if (mounted) _showPendingIpoAllocationIfNeeded();
  }

  Widget _ipoDialogValue(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppText(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        AppText(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

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
  }

  Future<void> _loadAppContent({bool force = false}) async {
    final content = await AppContentService.instance.load(force: force);
    if (!mounted) return;
    setState(() => _appContent = content);
  }

  Future<void> _loadHomeIndexHistory() async {
    const instruments = <(String, String, String)>[
      ('NIFTY 50', 'NIFTY50', 'NSE'),
      ('SENSEX', 'SENSEX', 'BSE'),
      ('BANK NIFTY', 'BANKNIFTY', 'NSE'),
      ('INDIA VIX', 'INDIAVIX', 'NSE'),
    ];
    final results = await Future.wait(
      instruments.map((instrument) async {
        try {
          final history = await marketDataService.fetchHistory(
            symbol: instrument.$2,
            exchange: instrument.$3,
            range: '1D',
          );
          return (
            instrument.$1,
            history.data.map((point) => point.close).toList(),
          );
        } catch (_) {
          return (instrument.$1, <double>[]);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result.$2.length >= 2) indexHistory[result.$1] = result.$2;
      }
    });
  }

  void _handleMarketConnection(bool connected) {
    if (!mounted || marketConnected == connected) return;
    setState(() => marketConnected = connected);
  }

  Future<void> _refreshMarketSession() async {
    final status = await marketDataService.fetchMarketSession();
    if (!mounted || status == null) return;
    final openTime = status['openTime']?.toString();
    final closeTime = status['closeTime']?.toString();
    setState(() {
      marketOpen = status['isOpen'] == true;
      if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
        marketHours = '$openTime - $closeTime IST';
      }
    });
  }

  Future<void> _refreshAccountSnapshot() async {
    try {
      final snapshot = await tradingService.fetchAccountSnapshot();
      if (!mounted || snapshot == null) return;
      setState(() {
        cashBalance = snapshot.cashBalance;
        buyingPower = snapshot.buyingPower;
        frozenBalance = snapshot.frozenBalance;
        realizedProfitLoss = snapshot.realizedProfitLoss;
        positions
          ..clear()
          ..addEntries(
            snapshot.positions.map(
              (position) => MapEntry(
                _positionKey(position.exchange, position.symbol),
                position,
              ),
            ),
          );
      });
    } catch (_) {
      // Keep the last known account values when a background refresh fails.
    }
  }

  Future<void> _refreshMarketData() async {
    final active = _marketRefreshInFlight;
    if (active != null) return active;
    _failedHomeLogoUrls.clear();
    final refresh = _performMarketRefresh();
    _marketRefreshInFlight = refresh;
    try {
      await refresh;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: AppText('Unable to refresh market data')),
          );
      }
    } finally {
      if (identical(_marketRefreshInFlight, refresh)) {
        _marketRefreshInFlight = null;
      }
    }
  }

  Future<void> _performMarketRefresh() async {
    unawaited(_loadAppContent(force: true));
    final results = await Future.wait<dynamic>([
      marketDataService.fetchSnapshot(),
      marketDataService.fetchIndexSnapshot(),
      marketDataService.fetchMarketSession(),
      marketDataService.fetchInstitutionalOffers(),
      marketDataService.fetchMarketNews(),
      marketDataService.fetchCompanyShowcase(),
    ]);
    if (!mounted) return;
    final refreshedStocks = results[0] as List<StockQuote>;
    final indices = results[1] as List<Map<String, dynamic>>;
    final session = results[2] as Map<String, dynamic>?;
    final refreshedInstitutional = results[3] as List<InstitutionalStock>;
    final refreshedNews = results[4] as List<MarketNewsItem>;
    final refreshedCompanies = results[5] as List<CompanyShowcase>;
    setState(() {
      if (refreshedStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(refreshedStocks);
      }
      companyShowcases
        ..clear()
        ..addAll(refreshedCompanies);
      for (final item in indices) {
        final symbol = item['symbol']?.toString().trim().toUpperCase();
        final price = double.tryParse(item['price']?.toString() ?? '');
        final change = double.tryParse(item['change']?.toString() ?? '') ?? 0;
        if (price == null) continue;
        if (symbol != null && symbol.isNotEmpty) {
          indexQuotes[symbol] = (price, change);
        }
        if (symbol == 'NIFTY50') {
          nifty50Price = price;
          nifty50Change = change;
        } else if (symbol == 'SENSEX') {
          sensexPrice = price;
          sensexChange = change;
        } else if (symbol == 'BANKNIFTY') {
          bankNiftyPrice = price;
          bankNiftyChange = change;
        }
      }
      if (session != null) {
        marketOpen = session['isOpen'] == true;
        final openTime = session['openTime']?.toString();
        final closeTime = session['closeTime']?.toString();
        if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
          marketHours = '$openTime - $closeTime IST';
        }
      }
      institutionalStocks
        ..clear()
        ..addAll(refreshedInstitutional);
      if (refreshedNews.isNotEmpty) {
        marketNews
          ..clear()
          ..addAll(refreshedNews);
      }
    });
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
    setState(() => _appContent = AppContentService.instance.current);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_refreshMarketData());
      unawaited(_refreshAccountSnapshot());
      unawaited(_refreshUnreadNotificationCount());
    }
  }

  Future<void> _loadAppData() async {
    final session = await AuthService().restoreSession();

    accountName = session?.fullName.isNotEmpty == true
        ? session!.fullName
        : 'Client';
    accountPhone = session?.phone ?? '';
    accountNumber = session?.accountNumber ?? '';
    if (accountPhone.isNotEmpty) {
      try {
        kycStatus = await AuthService().fetchKycStatus();
      } catch (_) {
        kycStatus = 'NOT_SUBMITTED';
      }
    }

    stocks.clear();
    ipos.clear();

    try {
      final remoteStocks = await marketDataService.fetchSnapshot();
      if (remoteStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(remoteStocks);
      }
    } catch (_) {
      // The service returns the last successful real snapshot when available.
    }

    try {
      final indices = await marketDataService.fetchIndexSnapshot();
      for (final item in indices) {
        final symbol = item['symbol']?.toString().trim().toUpperCase() ?? '';
        final price = double.tryParse(item['price']?.toString() ?? '');
        final change = double.tryParse(item['change']?.toString() ?? '') ?? 0;
        if (symbol.isEmpty || price == null) continue;
        indexQuotes[symbol] = (price, change);
        if (symbol == 'NIFTY50') {
          nifty50Price = price;
          nifty50Change = change;
        } else if (symbol == 'SENSEX') {
          sensexPrice = price;
          sensexChange = change;
        } else if (symbol == 'BANKNIFTY') {
          bankNiftyPrice = price;
          bankNiftyChange = change;
        }
      }
    } catch (_) {
      indexQuotes.clear();
    }

    try {
      final sessionStatus = await marketDataService.fetchMarketSession();
      if (sessionStatus != null) {
        marketOpen = sessionStatus['isOpen'] == true;
        final openTime = sessionStatus['openTime']?.toString();
        final closeTime = sessionStatus['closeTime']?.toString();
        if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
          marketHours = '$openTime - $closeTime IST';
        }
      }
    } catch (_) {}

    try {
      final snapshot = await tradingService.fetchAccountSnapshot();
      if (snapshot != null) {
        cashBalance = snapshot.cashBalance;
        buyingPower = snapshot.buyingPower;
        frozenBalance = snapshot.frozenBalance;
        realizedProfitLoss = snapshot.realizedProfitLoss;
        positions
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
    } catch (_) {}

    try {
      final remoteOrders = await tradingService.fetchOrders();
      orders
        ..clear()
        ..addAll(remoteOrders);
    } catch (_) {
      orders.clear();
    }

    try {
      final remoteInstitutional = await marketDataService
          .fetchInstitutionalOffers();
      institutionalStocks
        ..clear()
        ..addAll(remoteInstitutional);
    } catch (_) {
      institutionalStocks.clear();
    }

    try {
      final remoteWithdrawals = await AuthService().fetchWithdrawals();
      withdrawalRequests
        ..clear()
        ..addAll(remoteWithdrawals);
    } catch (_) {
      withdrawalRequests.clear();
    }

    try {
      final remoteIpos = await ipoService.fetchOpenIpos();
      final remoteApplications = await ipoService.fetchMyApplications();
      if (remoteIpos.isNotEmpty) {
        ipos
          ..clear()
          ..addAll(remoteIpos);
      }
      ipoApplications
        ..clear()
        ..addAll(remoteApplications);
    } catch (_) {
      ipoApplications.clear();
    }

    try {
      _profileData = await ClientAccountService().profile();
      final avatar = _profileData['avatarData'];
      profileAvatarBytes = avatar is String && avatar.isNotEmpty
          ? base64Decode(avatar)
          : null;
      final settings = await ClientAccountService().preferences();
      await AppLanguage.instance.select(
        settings['language']?.toString() ?? 'en',
      );
      await _loadAppContent(force: true);
      await AppearanceSettings.instance.select(
        settings['theme']?.toString() ?? 'light',
      );
      accountName = _profileData['fullName']?.toString() ?? accountName;
      accountPhone = _profileData['phone']?.toString() ?? accountPhone;
      accountNumber =
          _profileData['account']?['accountNumber']?.toString() ??
          accountNumber;
    } catch (_) {}

    try {
      final notifications = await ClientAccountService().notifications();
      unreadNotificationCount = notifications
          .where((item) => item['readAt'] == null)
          .length;
    } catch (_) {
      unreadNotificationCount = 0;
    }

    try {
      final latestNews = await marketDataService.fetchMarketNews();
      if (latestNews.isNotEmpty) {
        marketNews
          ..clear()
          ..addAll(latestNews);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        isLoading = false;
      });
      unawaited(_loadFeaturedStockHistory());
      unawaited(_loadPortfolioHistory(_portfolioPeriod));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || selectedIndex != 0) {
          return;
        }

        _showPendingIpoAllocationIfNeeded();
      });
    }
  }

  Future<void> _loadFeaturedStockHistory() async {
    final byInstrument = <String, StockQuote>{};
    for (final stock in <StockQuote>[
      ..._topMovers(gainers: true),
      ..._topMovers(gainers: false),
    ]) {
      byInstrument['${stock.exchange}:${stock.symbol}'] = stock;
    }
    final featured = byInstrument.values.toList();
    final results = await Future.wait(
      featured.map((stock) async {
        try {
          final history = await marketDataService.fetchHistory(
            symbol: stock.symbol,
            exchange: stock.exchange,
            range: '1D',
          );
          return (
            stock.symbol,
            history.data.map((point) => point.close).toList(),
          );
        } catch (_) {
          return (stock.symbol, <double>[]);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final result in results) {
        if (result.$2.length >= 2) stockHistory[result.$1] = result.$2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: _selectedBody(),
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
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: NavigationBar(
                height: AppSpacing.navHeight,
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
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.bar_chart_outlined),
                    selectedIcon: const Icon(
                      Icons.bar_chart,
                      color: AppColors.navSelected,
                    ),
                    label: tr('Markets'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.swap_horiz_rounded),
                    selectedIcon: const Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.navSelected,
                    ),
                    label: tr('Trade'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.pie_chart_outline),
                    selectedIcon: const Icon(
                      Icons.pie_chart,
                      color: AppColors.navSelected,
                    ),
                    label: tr('Portfolio'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(
                      Icons.person,
                      color: AppColors.navSelected,
                    ),
                    label: tr('Profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDestinationSelected(int index) {
    setState(() {
      selectedIndex = index;
    });

    if (index == 3) {
      unawaited(_loadPortfolioHistory(_portfolioPeriod));
      unawaited(_refreshAccountSnapshot());
    }

    if (index == 1) {
      unawaited(_refreshMarketData());
    }

    if (index == 4) {
      unawaited(_refreshMembership());
      unawaited(_refreshUnreadNotificationCount());
      unawaited(_refreshAccountSnapshot());
    }

    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _showPendingIpoAllocationIfNeeded();
      });
    }
  }

  Future<void> _refreshMembership() async {
    try {
      final profile = await ClientAccountService().profile();
      if (!mounted) return;
      setState(() => _profileData = profile);
    } catch (_) {
      // Retain the last server-confirmed profile during a network interruption.
    }
  }

  Widget _selectedBody() {
    switch (selectedIndex) {
      case 0:
        return _marketBody();

      case 1:
        return MarketsPage(
          stocks: stocks,
          nifty50Price: nifty50Price,
          nifty50Change: nifty50Change,
          sensexPrice: sensexPrice,
          sensexChange: sensexChange,
          bankNiftyPrice: bankNiftyPrice,
          bankNiftyChange: bankNiftyChange,
          indexQuotes: indexQuotes,
          notificationCount: unreadNotificationCount,
          onNotifications: _openNotifications,
          onStockTap: _openStock,
          onRefresh: _refreshMarketData,
        );

      case 2:
        return TradingCenterPage(
          stocks: stocks,
          positions: positions,
          orders: orders,
          institutionalStocks: institutionalStocks,
          ipos: ipos,
          ipoApplications: ipoApplications,
          onTrade: _openStock,
          onApplyIpo: _applyIpo,
          onAlertsTap: _openNotifications,
          notificationCount: unreadNotificationCount,
          indexQuotes: indexQuotes,
          onViewMarkets: () => setState(() => selectedIndex = 1),
        );

      case 3:
        return _portfolioBody();

      case 4:
        return _accountBody();

      default:
        return _marketBody();
    }
  }

  Widget _homeFundsCard() {
    double outstandingIpo = 0;
    double holdingsValue = 0;

    for (final application in ipoApplications) {
      if (application.status == IpoApplicationStatus.allocated &&
          application.remainingAmount > 0) {
        outstandingIpo += application.remainingAmount;
      }
    }

    for (final position in positions.values) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      holdingsValue += position.marketValue(
        stock?.price ?? position.averageCost,
      );
    }

    final totalPortfolioValue = cashBalance + holdingsValue;
    final todayPnl = positions.values.fold<double>(0, (total, position) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      return total +
          position.unrealizedProfitLoss(stock?.price ?? position.averageCost);
    });
    final pnlPositive = todayPnl >= 0;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 18),
          decoration: AppUi.heroGradient(radius: AppUi.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      _appContent.text(
                        'home',
                        'funds.total_asset_label',
                        fallback: 'Total Asset Value',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _amountsHidden ? 'Show balances' : 'Hide balances',
                    onPressed: () =>
                        setState(() => _amountsHidden = !_amountsHidden),
                    icon: Icon(
                      _amountsHidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Profit period',
                    onSelected: (period) =>
                        unawaited(_loadPortfolioHistory(period)),
                    itemBuilder: (_) => ['1D', '1W', '1M', '3M', '1Y', 'All']
                        .map(
                          (period) => PopupMenuItem(
                            value: period,
                            child: AppText(period),
                          ),
                        )
                        .toList(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          _portfolioPeriod,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Icon(
                          Icons.expand_more,
                          color: Colors.white,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: AppText(
                      _amountsHidden
                          ? '******'
                          : formatPrice(totalPortfolioValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: MediaQuery.sizeOf(context).width < 360 ? 90 : 116,
                    height: 38,
                    child: !_amountsHidden && _portfolioSeries.length >= 2
                        ? CustomPaint(
                            painter: MiniLineChartPainter(
                              color: AppConfig.chartGainColor,
                              values: _portfolioSeries,
                            ),
                          )
                        : const Center(
                            child: AppText(
                              '--',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              AppText(
                _amountsHidden
                    ? '******'
                    : _portfolioHistoryLoading
                    ? 'Loading returns...'
                    : _periodProfit == null
                    ? 'Insufficient history'
                    : '${formatPrice(_periodProfit!)} · $_portfolioPeriod',
                style: TextStyle(
                  color: (_periodProfit ?? 0) == 0
                      ? Colors.white70
                      : (_periodProfit ?? 0) > 0
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_historyError != null)
                AppText(
                  _historyError!,
                  style: const TextStyle(color: Colors.white70),
                ),
              if (_historyFrom != null && !_amountsHidden)
                AppText(
                  'Since $_historyFrom',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              if (outstandingIpo > 0) ...[
                const SizedBox(height: 10),
                AppText(
                  _amountsHidden
                      ? '******'
                      : 'IPO Funds Required ${formatPrice(outstandingIpo)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _homeQuickActions(),
        if (companyShowcases.isNotEmpty) ...[
          const SizedBox(height: 18),
          _sectionTitle(
            _appContent.text(
              'home',
              'company.section_title',
              fallback: 'Our Company',
            ),
          ),
          const SizedBox(height: 10),
          _companyShowcaseCard(companyShowcases.first),
        ],
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: AppUi.surface(radius: AppUi.radiusMd),
          child: Row(
            children: [
              Expanded(
                child: _homeBalanceValue(
                  'Available Funds',
                  availableBalance,
                  AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 58, child: VerticalDivider(width: 1)),
              Expanded(
                child: _homeBalanceValue(
                  'Used Margin',
                  frozenBalance,
                  AppConfig.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 58, child: VerticalDivider(width: 1)),
              Expanded(
                child: _homeBalanceValue(
                  'Unrealized P&L',
                  todayPnl,
                  pnlPositive ? AppConfig.gainColor : AppConfig.lossColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _homeBalanceValue(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AppText(
              _amountsHidden
                  ? '******'
                  : label.contains('P&L')
                  ? formatSignedPrice(value)
                  : formatPrice(value),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _companyShowcaseCard(CompanyShowcase company) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1F44), Color(0xFF123B72), Color(0xFF176B88)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33152F5F),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -34,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: company.logoUrl?.isNotEmpty == true
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                company.logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.business_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.business_rounded,
                              color: Colors.white,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            company.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          AppText(
                            company.tagline,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD5E6FF),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF8DE7D3),
                      size: 22,
                    ),
                  ],
                ),
                if (company.videoUrl?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => launchUrl(Uri.parse(company.videoUrl!)),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFF07152F),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Color(0xFF123B72),
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AppText(
                              _appContent.text(
                                'home',
                                'company.video_cta',
                                fallback: 'Watch our company introduction',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppText(
                  company.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE7F0FF),
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (company.sector?.isNotEmpty == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: AppText(
                          company.sector!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (company.websiteUrl?.isNotEmpty == true)
                      TextButton.icon(
                        onPressed: () =>
                            launchUrl(Uri.parse(company.websiteUrl!)),
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        label: Text(
                          _appContent.text(
                            'home',
                            'company.website_cta',
                            fallback: 'Visit website',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeQuickActions() {
    return Row(
      children: [
        Expanded(
          child: HomeActionButton(
            label: _appContent.text(
              'home',
              'funds.cta_label',
              fallback: 'Add Funds',
            ),
            subtitle: _appContent.text(
              'home',
              'funds.cta_subtitle',
              fallback: 'Contact support to fund',
            ),
            icon: Icons.account_balance_wallet_outlined,
            color: AppConfig.primaryColor,
            onTap: _openDepositSupport,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: HomeActionButton(
            label: _appContent.text(
              'home',
              'funds.withdraw_cta_label',
              fallback: 'Withdraw Funds',
            ),
            subtitle: _appContent.text(
              'home',
              'funds.withdraw_cta_subtitle',
              fallback: 'Transfer to Bank',
            ),
            icon: Icons.call_made_rounded,
            color: const Color(0xFF0F766E),
            onTap: _openWithdrawalRequest,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, {VoidCallback? onViewAll}) {
    return Row(
      children: [
        Expanded(child: AppText(title, style: AppUi.sectionTitle)),
        if (onViewAll != null)
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onViewAll,
            child: AppText(
              _appContent.text('home', 'view_all_cta', fallback: 'View All'),
            ),
          ),
      ],
    );
  }

  Widget _marketIndicesStrip() {
    final vix =
        indexQuotes['INDIAVIX'] ??
        indexQuotes['INDIA VIX'] ??
        indexQuotes['VIX'];
    final indices = [
      (
        'NIFTY 50',
        nifty50Price > 0 ? formatIndex(nifty50Price) : '--',
        nifty50Change,
      ),
      (
        'SENSEX',
        sensexPrice > 0 ? formatIndex(sensexPrice) : '--',
        sensexChange,
      ),
      (
        'BANK NIFTY',
        bankNiftyPrice > 0 ? formatIndex(bankNiftyPrice) : '--',
        bankNiftyChange,
      ),
      (
        'INDIA VIX',
        vix != null && vix.$1 > 0 ? formatIndex(vix.$1) : '--',
        vix?.$2 ?? 0,
      ),
    ];

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: indices.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = indices[index];
          final available = item.$2 != '--';
          final positive = item.$3 >= 0;
          final color = !available
              ? AppConfig.neutralColor
              : positive
              ? AppConfig.gainColor
              : AppConfig.lossColor;
          return Container(
            width: 148,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8EDF5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                AppText(
                  item.$2,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                AppText(
                  available
                      ? '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%'
                      : 'Unavailable',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _compactMovers() {
    final gainers = _topMovers(gainers: true);
    final losers = _topMovers(gainers: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return Column(
            children: [
              _compactMoverList('Top Gainers', gainers, true),
              const SizedBox(height: 10),
              _compactMoverList('Top Losers', losers, false),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _compactMoverList('Top Gainers', gainers, true)),
            const SizedBox(width: 10),
            Expanded(child: _compactMoverList('Top Losers', losers, false)),
          ],
        );
      },
    );
  }

  final Set<String> _failedHomeLogoUrls = {};

  List<StockQuote> _topMovers({required bool gainers}) {
    final movers = stocks
        .where(
          (stock) =>
              stock.price > 0 &&
              stock.logoUrl?.trim().isNotEmpty == true &&
              !_failedHomeLogoUrls.contains(stock.logoUrl) &&
              stock.change.isFinite &&
              (gainers ? stock.change > 0 : stock.change < 0),
        )
        .toList();
    movers.sort(
      (left, right) => gainers
          ? right.change.compareTo(left.change)
          : left.change.compareTo(right.change),
    );
    return movers.take(5).toList();
  }

  Widget _compactMoverList(String title, List<StockQuote> list, bool positive) {
    final color = positive ? AppConfig.gainColor : AppConfig.lossColor;
    final items = list.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => selectedIndex = 1),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: AppText(
                    'View All',
                    style: TextStyle(
                      color: AppConfig.primaryColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: AppText(
                positive
                    ? 'No gainers available with logos'
                    : 'No losers available with logos',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ),
          ...items.map(
            (stock) => InkWell(
              onTap: () => _openStock(stock),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    StockLogo(
                      symbol: stock.symbol,
                      logoUrl: stock.logoUrl,
                      size: 20,
                      onLoadFailed: () {
                        if (!mounted ||
                            stock.logoUrl == null ||
                            _failedHomeLogoUrls.contains(stock.logoUrl)) {
                          return;
                        }
                        setState(() => _failedHomeLogoUrls.add(stock.logoUrl!));
                      },
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppText(
                        _shortStockName(stock),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((stockHistory[stock.symbol]?.length ?? 0) >= 2) ...[
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 34,
                        height: 16,
                        child: CustomPaint(
                          painter: MiniLineChartPainter(
                            color: stock.change >= 0
                                ? AppConfig.gainColor
                                : AppConfig.lossColor,
                            values: stockHistory[stock.symbol]!,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 54,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          FittedBox(
                            child: AppText(
                              formatPrice(stock.price),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          AppText(
                            '${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortStockName(StockQuote stock) {
    const names = {
      'HDFCBANK': 'HDFC Bank',
      'RELIANCE': 'Reliance Ind.',
      'TCS': 'TCS',
      'ICICIBANK': 'ICICI Bank',
      'INFY': 'Infosys',
      'ITC': 'ITC',
      'HINDUNILVR': 'Hind. Unilever',
      'NESTLEIND': 'Nestle India',
      'LT': 'L&T',
      'TITAN': 'Titan Company',
    };
    return names[stock.symbol] ?? stock.name;
  }

  void _openDepositSupport() {
    // APP Add Funds opens the in-app Deposit page (not the side Support button).
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DepositPage()));
  }

  Future<void> _openWithdrawalRequest() async {
    if (_withdrawalSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _appContent.text(
              'home',
              'withdraw.submitting',
              fallback: 'A withdrawal request is being submitted',
            ),
          ),
        ),
      );
      return;
    }
    try {
      if (!await ClientAccountService().hasWithdrawalPin()) {
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AccountSecurityPage(withdrawalPin: true),
            ),
          );
        }
        return;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.toString())));
      }
      return;
    }
    final latestWithdrawals = await AuthService().fetchWithdrawals();
    withdrawalRequests
      ..clear()
      ..addAll(latestWithdrawals);
    var availableWithdrawalBalance = availableBalance;
    List<Map<String, dynamic>> bankAccounts;
    try {
      bankAccounts = await ClientAccountService().banks();
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(error.message)));
      }
      return;
    }
    if (!mounted) return;
    if (bankAccounts.isEmpty) {
      await _openAccountSettings('banks');
      return;
    }
    var selectedBank = bankAccounts.firstWhere(
      (bank) => bank['isPrimary'] == true,
      orElse: () => bankAccounts.first,
    );
    final initialBankNumber = selectedBank['accountNumber']?.toString() ?? '';
    final initialIfsc = selectedBank['ifscCode']?.toString() ?? '';
    if (initialBankNumber.trim().isEmpty || initialIfsc.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              _appContent.text(
                'home',
                'withdraw.bank_incomplete',
                fallback:
                    'Complete your bank account details before withdrawing',
              ),
            ),
          ),
        );
      }
      await _openAccountSettings('banks');
      return;
    }
    final amountController = TextEditingController();
    final pinController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              title: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppConfig.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppText(
                      _appContent.text(
                        'home',
                        'withdraw.dialog_title',
                        fallback: 'Withdrawal Request',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      _appContent.text(
                        'home',
                        'withdraw.available_label',
                        fallback: 'Available Funds',
                      ),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      formatPrice(availableWithdrawalBalance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      _appContent
                          .text(
                            'home',
                            'withdraw.frozen_template',
                            fallback: 'Total frozen: {amount}',
                          )
                          .replaceAll('{amount}', formatPrice(frozenBalance)),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,13}([.]\d{0,2})?$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: _appContent.text(
                          'home',
                          'withdraw.amount_label',
                          fallback: 'Withdrawal Amount',
                        ),
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        errorText: errorText == null ? null : tr(errorText!),
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppText(
                      _appContent.text(
                        'home',
                        'withdraw.min_hint',
                        fallback: 'Minimum withdrawal: ₹100',
                      ),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),

                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      enableSuggestions: false,
                      autocorrect: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        labelText: _appContent.text(
                          'home',
                          'withdraw.pin_label',
                          fallback: 'Withdrawal PIN',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_outlined,
                                size: 20,
                                color: AppConfig.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              AppText(
                                _appContent.text(
                                  'home',
                                  'withdraw.bank_section_title',
                                  fallback: 'Withdrawal Bank Account',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: selectedBank['id']?.toString(),
                            decoration: InputDecoration(
                              labelText: _appContent.text(
                                'home',
                                'withdraw.bank_picker_label',
                                fallback: 'Bank account',
                              ),
                            ),
                            items: bankAccounts.map((bank) {
                              final number =
                                  bank['accountNumber']?.toString() ?? '';
                              final suffix = number.length > 4
                                  ? number.substring(number.length - 4)
                                  : number;
                              return DropdownMenuItem(
                                value: bank['id']?.toString(),
                                child: AppText(
                                  '${bank['bankName']} ••••$suffix',
                                ),
                              );
                            }).toList(),
                            onChanged: (id) => setDialogState(() {
                              selectedBank = bankAccounts.firstWhere(
                                (bank) => bank['id']?.toString() == id,
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          _withdrawBankRow(
                            _appContent.text(
                              'home',
                              'withdraw.holder_label',
                              fallback: 'Account Holder',
                            ),
                            selectedBank['accountHolder']?.toString() ??
                                accountName,
                          ),
                          const SizedBox(height: 10),
                          _withdrawBankRow(
                            _appContent.text(
                              'home',
                              'withdraw.account_label',
                              fallback: 'Bank Account',
                            ),
                            selectedBank['accountNumber']?.toString() ?? '',
                          ),
                          const SizedBox(height: 10),
                          _withdrawBankRow(
                            _appContent.text(
                              'home',
                              'withdraw.status_label',
                              fallback: 'Bank Status',
                            ),
                            selectedBank['status']?.toString() ?? 'Added',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    AppText(
                      _appContent.text(
                        'home',
                        'withdraw.notice',
                        fallback:
                            'Submit here in the app. Finance reviews your request. '
                            'The amount is frozen right away. Approval deducts cash; '
                            'rejection releases the freeze.',
                      ),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: AppText(
                            _appContent.text(
                              'home',
                              'withdraw.records_title',
                              fallback: 'Withdrawal Records',
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              final latest = await AuthService()
                                  .fetchWithdrawals();
                              final snapshot = await tradingService
                                  .fetchAccountSnapshot();
                              if (!mounted) return;
                              setState(() {
                                withdrawalRequests
                                  ..clear()
                                  ..addAll(latest);
                                if (snapshot != null) {
                                  cashBalance = snapshot.cashBalance;
                                  buyingPower = snapshot.buyingPower;
                                  frozenBalance = snapshot.frozenBalance;
                                }
                              });
                              setDialogState(() {
                                availableWithdrawalBalance = availableBalance;
                              });
                            } on AuthException catch (error) {
                              if (!dialogContext.mounted) return;
                              ScaffoldMessenger.of(
                                dialogContext,
                              ).hideCurrentSnackBar();
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: AppText(error.message)),
                              );
                            }
                          },
                          child: const AppText('Refresh'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (withdrawalRequests.isEmpty)
                      const AppText(
                        'No withdrawal records yet.',
                        style: TextStyle(color: Colors.black54),
                      )
                    else
                      ...withdrawalRequests
                          .take(5)
                          .map((request) => _withdrawalRecordTile(request)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: AppText(
                    _appContent.text(
                      'home',
                      'withdraw.cancel',
                      fallback: 'Cancel',
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim().replaceAll(',', ''),
                    );

                    if (amount == null || amount < _minimumWithdrawalAmount) {
                      setDialogState(() {
                        errorText = _appContent.text(
                          'home',
                          'withdraw.min_error',
                          fallback: 'Minimum withdrawal amount is ₹100',
                        );
                      });
                      return;
                    }

                    if (amount > availableWithdrawalBalance) {
                      setDialogState(() {
                        errorText = _appContent
                            .text(
                              'home',
                              'withdraw.max_error_template',
                              fallback: 'Maximum available: {amount}',
                            )
                            .replaceAll(
                              '{amount}',
                              formatPrice(availableWithdrawalBalance),
                            );
                      });
                      return;
                    }

                    if ((selectedBank['accountNumber']?.toString().trim() ?? '')
                            .isEmpty ||
                        (selectedBank['ifscCode']?.toString().trim() ?? '')
                            .isEmpty) {
                      setDialogState(() {
                        errorText = _appContent.text(
                          'home',
                          'withdraw.bank_error',
                          fallback: 'Select a complete bank account',
                        );
                      });
                      return;
                    }

                    if (!RegExp(r'^\d{6}$').hasMatch(pinController.text)) {
                      setDialogState(
                        () => errorText = _appContent.text(
                          'home',
                          'withdraw.pin_error',
                          fallback: 'Enter a 6-digit PIN',
                        ),
                      );
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: AppText(
                    _appContent.text(
                      'home',
                      'withdraw.submit',
                      fallback: 'Submit Request',
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) {
      amountController.dispose();
      pinController.dispose();
      return;
    }

    final amount =
        double.tryParse(amountController.text.trim().replaceAll(',', '')) ?? 0;

    amountController.dispose();
    final withdrawalPin = pinController.text;
    pinController.dispose();

    if (amount < _minimumWithdrawalAmount ||
        amount > availableWithdrawalBalance) {
      return;
    }

    late final WithdrawalRequest request;
    TradingAccountSnapshot? updatedSnapshot;

    setState(() => _withdrawalSubmitting = true);
    try {
      request = await AuthService().submitWithdrawal(
        withdrawalPin: withdrawalPin,
        amount: amount,
        bankName: selectedBank['bankName']?.toString() ?? '',
        accountNumber: selectedBank['accountNumber']?.toString() ?? '',
        ifscCode: selectedBank['ifscCode']?.toString() ?? '',
        note: 'App withdrawal request',
      );
      try {
        updatedSnapshot = await tradingService.fetchAccountSnapshot();
      } catch (_) {
        updatedSnapshot = null;
      }
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: AppText('Unable to submit withdrawal. Please try again.'),
          ),
        );
      return;
    } finally {
      if (mounted) setState(() => _withdrawalSubmitting = false);
    }

    setState(() {
      withdrawalRequests.insert(0, request);
      final snapshot = updatedSnapshot;
      if (snapshot != null) {
        cashBalance = snapshot.cashBalance;
        buyingPower = snapshot.buyingPower;
        frozenBalance = snapshot.frozenBalance;
      } else {
        buyingPower = math.max(0, buyingPower - amount).toDouble();
        frozenBalance += amount;
      }
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText(
          'Withdrawal request ${request.orderNo ?? request.id} submitted. '
          'Funds are frozen while finance reviews it.',
        ),
      ),
    );
  }

  Widget _withdrawalRecordTile(WithdrawalRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  request.orderNo ?? request.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              AppText(
                request.statusLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: AppText(formatPrice(request.amount))),
              AppText(
                '${request.createdAt.day.toString().padLeft(2, '0')}/'
                '${request.createdAt.month.toString().padLeft(2, '0')}/'
                '${request.createdAt.year}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          AppText(
            request.fundsStatusLabel,
            style: TextStyle(
              color: request.status == WithdrawalStatus.rejected
                  ? AppConfig.lossColor
                  : request.status == WithdrawalStatus.approved ||
                        request.status == WithdrawalStatus.completed
                  ? AppConfig.gainColor
                  : const Color(0xFFD97706),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _withdrawBankRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: AppText(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        AppText(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _marketBody() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 16.0;
    return Container(
      color: AppConfig.backgroundColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          14,
          horizontalPadding,
          24,
        ),
        children: [
          MarketHeader(
            accountName: accountName,
            avatarBytes: profileAvatarBytes,
            onAvatarTap: _pickProfileAvatar,
            onSearchTap: _openStockSearch,
            onNotificationTap: _openNotifications,
            notificationCount: unreadNotificationCount,
          ),
          const SizedBox(height: 10),
          const MarketStatusCard(),
          const SizedBox(height: 14),
          _homeFundsCard(),
          const SizedBox(height: 18),
          _sectionTitle(
            _appContent.text(
              'home',
              'indices.section_title',
              fallback: 'Market Indices',
            ),
            onViewAll: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 10),
          _marketIndicesStrip(),
          const SizedBox(height: 18),
          _compactMovers(),
          const SizedBox(height: 18),
          _sectionTitle(
            _appContent.text(
              'home',
              'news.section_title',
              fallback: 'Market News',
            ),
            onViewAll: marketNews.isEmpty
                ? null
                : () => unawaited(_openAllMarketNews()),
          ),
          const SizedBox(height: 10),
          _marketNewsSection(),
          const SizedBox(height: 14),
          _homeTradingBanner(),
        ],
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

  Future<void> _reloadNews() async {
    final latest = await marketDataService.fetchMarketNews();
    if (!mounted) return;
    if (latest.isNotEmpty) {
      setState(() {
        marketNews
          ..clear()
          ..addAll(latest);
      });
    }
  }

  Widget _marketNewsSection() {
    if (marketNews.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(Icons.newspaper_outlined, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: AppText(
                  _appContent.text(
                    'home',
                    'news.empty',
                    fallback: 'Live market news is temporarily unavailable.',
                  ),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              IconButton(
                onPressed: _reloadNews,
                tooltip: 'Retry news',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final oneColumn = constraints.maxWidth < 340;
        final width = oneColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: marketNews
              .take(2)
              .map(
                (item) => SizedBox(
                  width: width,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openNews(item),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      height: oneColumn ? 154 : 168,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE8EDF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 78,
                            child: item.imageUrl?.isNotEmpty == true
                                ? Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const ColoredBox(
                                        color: Color(0xFFF2F6FC),
                                        child: Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, _, _) => const ColoredBox(
                                      color: Color(0xFFEEF5FF),
                                      child: Icon(
                                        Icons.candlestick_chart_rounded,
                                        color: AppConfig.primaryColor,
                                        size: 32,
                                      ),
                                    ),
                                  )
                                : const ColoredBox(
                                    color: Color(0xFFEEF5FF),
                                    child: Icon(
                                      Icons.candlestick_chart_rounded,
                                      color: AppConfig.primaryColor,
                                      size: 32,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(11),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppText(
                                  item.title,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    height: 1.28,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                AppText(
                                  '${item.source}  ·  ${_newsAge(item.publishedAt)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  String _newsAge(DateTime publishedAt) {
    final difference = DateTime.now().difference(publishedAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Future<void> _openNews(MarketNewsItem item) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      _showNewsOpenError();
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showNewsOpenError();
    } catch (_) {
      _showNewsOpenError();
    }
  }

  Future<void> _openAllMarketNews() async {
    final latest = await marketDataService.fetchMarketNews(limit: 50);
    if (!mounted) return;
    final items = latest.isNotEmpty
        ? latest
        : List<MarketNewsItem>.from(marketNews);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MarketNewsPage(
          items: items,
          onOpen: _openNews,
          onRefresh: () => marketDataService.fetchMarketNews(limit: 50),
        ),
      ),
    );
  }

  void _showNewsOpenError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: AppText('Unable to open this news article')),
      );
  }

  Widget _homeTradingBanner() {
    final title = _appContent.text(
      'home',
      'banner.title',
      fallback: 'Track live markets & place orders on the go',
    );
    final subtitle = _appContent.text(
      'home',
      'banner.subtitle',
      fallback: 'Explore equities, institutional offers, OTC and IPOs',
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.candlestick_chart_rounded,
            size: 52,
            color: AppConfig.gainColor,
          ),
        ],
      ),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));
    await _refreshUnreadNotificationCount();
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final notifications = await ClientAccountService().notifications();
      if (!mounted) return;
      setState(() {
        unreadNotificationCount = notifications
            .where((item) => item['readAt'] == null)
            .length;
      });
    } catch (_) {
      // Preserve the current badge when the server cannot be reached.
    }
  }

  String get _accountInitials {
    final parts = accountName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
        ),
        if (unreadNotificationCount > 0)
          Positioned(
            right: 7,
            top: 5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFEF233C),
                shape: BoxShape.circle,
              ),
              child: AppText(
                unreadNotificationCount > 9
                    ? '9+'
                    : unreadNotificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openStock(StockQuote stock) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StockDetailPage(stock: stock, onOrderPlaced: _placeOrder),
      ),
    );
  }

  void _openStockSearch() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            StockSearchPage(initialStocks: stocks, onSelected: _openStock),
      ),
    );
  }

  Future<String?> _placeOrder(TradingOrder order) async {
    final existing = positions[_positionKey(order.exchange, order.symbol)];

    if (order.isBuy && order.amount > buyingPower) {
      return 'Insufficient buying power. Available: '
          '${formatPrice(buyingPower)}';
    }

    if (!order.isBuy &&
        (existing == null || existing.availableQuantity < order.quantity)) {
      return 'Insufficient holdings. Available: '
          '${existing?.availableQuantity ?? 0}';
    }

    try {
      final confirmedOrder = await tradingService.placeMarketOrder(order);
      final snapshot = await tradingService
          .fetchAccountSnapshot(allowCached: false)
          .catchError((_) => null);
      final remoteOrders = await tradingService
          .fetchOrders(allowCached: false)
          .catchError((_) => <TradingOrder>[]);
      if (!mounted) return null;
      final updatedOrders = mergeConfirmedOrder(
        confirmedOrder,
        remoteOrders.isNotEmpty ? remoteOrders : orders,
      );

      if (snapshot != null) {
        setState(() {
          cashBalance = snapshot.cashBalance;
          buyingPower = snapshot.buyingPower;
          frozenBalance = snapshot.frozenBalance;
          realizedProfitLoss = snapshot.realizedProfitLoss;
          positions
            ..clear()
            ..addEntries(
              snapshot.positions.map(
                (position) => MapEntry(
                  _positionKey(position.exchange, position.symbol),
                  position,
                ),
              ),
            );
          orders
            ..clear()
            ..addAll(updatedOrders);
        });

        return null;
      }

      setState(() {
        orders
          ..clear()
          ..addAll(updatedOrders);
      });

      return null;
    } catch (error) {
      return error.toString();
    }
  }

  Widget _portfolioBody() => ProductPortfolioPage(
    onExplore: () => setState(() => selectedIndex = 2),
    onNotifications: _openNotifications,
  );

  Future<void> _loadPortfolioHistory(String period) async {
    final requestId = ++_portfolioHistoryRequest;
    setState(() {
      _portfolioPeriod = period;
      _portfolioHistoryLoading = true;
      _portfolioSeries = const [];
      _periodProfit = null;
      _historyFrom = null;
      _historyError = null;
    });
    try {
      final result = await ClientAccountService().assetHistory(period);
      if (!mounted || requestId != _portfolioHistoryRequest) return;
      final points = (result['points'] as List? ?? [])
          .whereType<Map>()
          .toList();
      setState(() {
        _portfolioSeries = points
            .map((p) => (p['totalValue'] as num).toDouble())
            .toList();
        _periodProfit = (result['profitChange'] as num?)?.toDouble();
        final from = DateTime.tryParse(result['from']?.toString() ?? '');
        _historyFrom = from?.toLocal().toString().substring(0, 16);
      });
    } catch (_) {
      if (mounted && requestId == _portfolioHistoryRequest) {
        setState(() => _historyError = 'History unavailable. Try again later.');
      }
    } finally {
      if (mounted && requestId == _portfolioHistoryRequest) {
        setState(() => _portfolioHistoryLoading = false);
      }
    }
  }

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

  Widget _profileHeader() {
    final phone = accountPhone.isEmpty
        ? '--'
        : accountPhone.startsWith('+')
        ? accountPhone
        : '+91 $accountPhone';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.primaryDarkColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: tr('Edit profile photo'),
                child: InkWell(
                  onTap: _pickProfileAvatar,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: profileAvatarBytes == null
                        ? null
                        : MemoryImage(profileAvatarBytes!),
                    child: profileAvatarBytes == null
                        ? AppText(
                            _accountInitials,
                            style: const TextStyle(
                              color: AppConfig.primaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      accountName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
                      phone,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AppText(
                      '${tr('Account ID')}: $accountNumber',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _profileStatusPill(
                          icon: kycStatus == 'APPROVED'
                              ? Icons.verified
                              : Icons.info_outline,
                          iconColor: kycStatus == 'APPROVED'
                              ? const Color(0xFF45D59A)
                              : Colors.white70,
                          label: kycStatus == 'APPROVED'
                              ? 'KYC Verified'
                              : kycStatus == 'PENDING'
                              ? 'KYC Pending Review'
                              : 'KYC Required',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('Edit profile'),
                onPressed: _editProfile,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in <(String, String)>[
                ('Client Tier', _profileData['clientTier']?.toString() ?? '--'),
                (
                  'Member Since',
                  _profileData['createdAt']?.toString().split('T').first ??
                      '--',
                ),
                ('Account Status', _profileData['status']?.toString() ?? '--'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          item.$1,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 5),
                        if (item.$1 == 'Client Tier')
                          MembershipTierBadge(tier: item.$2)
                        else
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                item.$1 == 'Member Since'
                                    ? Icons.calendar_month_outlined
                                    : Icons.check_circle_outline,
                                size: 18,
                                color: item.$2 == 'ACTIVE'
                                    ? const Color(0xff70e0ba)
                                    : Colors.white70,
                              ),
                              AppText(
                                item.$2,
                                style: TextStyle(
                                  color: item.$2 == 'ACTIVE'
                                      ? const Color(0xff70e0ba)
                                      : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountBody() {
    final holdingsValue = positions.values
        .where((position) => portfolioCategory(position.category) != null)
        .fold<double>(0, (total, position) {
          final stock = _stockForOrNull(
            position.symbol,
            exchange: position.exchange,
          );
          return total +
              position.marketValue(stock?.price ?? position.averageCost);
        });

    final productValue = holdingsValue;
    final totalReturns = positions.values
        .where((position) => portfolioCategory(position.category) != null)
        .fold<double>(0, (total, position) {
          final stock = _stockForOrNull(
            position.symbol,
            exchange: position.exchange,
          );
          return total +
              position.realizedProfitLoss +
              position.unrealizedProfitLoss(
                stock?.price ?? position.averageCost,
              );
        });

    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md + 2
        : AppSpacing.lg;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        AppSpacing.md + 2,
        horizontalPadding,
        AppSpacing.xxl,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: AppText(
                _appContent.text(
                  'home',
                  'profile.page_title',
                  fallback: 'Profile',
                ),
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _notificationButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.md + 2),
        _profileHeader(),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text(
            'home',
            'profile.section.overview',
            fallback: 'Account Overview',
          ),
          style: AppUi.sectionTitle,
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.xs,
          ),
          decoration: AppUi.surface(radius: AppRadius.md),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _homeBalanceValue(
                    _appContent.text(
                      'home',
                      'profile.metric.available',
                      fallback: 'Available Balance',
                    ),
                    availableBalance,
                    AppColors.textPrimary,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _homeBalanceValue(
                    _appContent.text(
                      'home',
                      'profile.metric.portfolio',
                      fallback: 'Product Holdings',
                    ),
                    productValue,
                    AppColors.textPrimary,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _homeBalanceValue(
                    _appContent.text(
                      'home',
                      'profile.metric.returns',
                      fallback: 'Total Returns',
                    ),
                    totalReturns,
                    totalReturns >= 0 ? AppColors.gain : AppColors.loss,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text(
            'home',
            'profile.section.account',
            fallback: 'Account',
          ),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: 'Account ID and full name',
                onTap: _editProfile,
                color: AppColors.brandPrimary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.verified_user_outlined,
                title: 'KYC Verification',
                subtitle: 'Identity documents and verification status',
                status: kycStatus == 'APPROVED'
                    ? 'Verified'
                    : kycStatus == 'PENDING'
                    ? 'Pending'
                    : 'Required',
                onTap: () => _openAccountSettings('kyc'),
                color: AppColors.gain,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank Accounts',
                subtitle: 'Manage linked bank accounts and UPI',
                onTap: () => _openAccountSettings('banks'),
                color: AppColors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text('home', 'profile.section.funds', fallback: 'Funds'),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.request_quote_outlined,
                title: 'Loan Applications',
                subtitle: 'Application status',
                color: AppColors.gain,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoanPage()),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text(
            'home',
            'profile.section.security',
            fallback: 'Security',
          ),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.password_outlined,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSecurityPage(),
                  ),
                ),
                color: AppColors.brandPrimary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.security_outlined,
                title: 'Two-Factor Authentication',
                subtitle: 'Authenticator and recovery codes',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TwoFactorPage(),
                  ),
                ),
                color: AppColors.info,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.pin_outlined,
                title: 'Transaction PIN',
                subtitle: 'Set or change your withdrawal password',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const AccountSecurityPage(withdrawalPin: true),
                  ),
                ),
                color: AppColors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text(
            'home',
            'profile.section.preferences',
            fallback: 'Preferences',
          ),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.notifications_none_rounded,
                title: 'Alert Preferences',
                subtitle: 'Choose which account updates you receive',
                onTap: () => _openAccountSettings('preferences'),
                color: AppColors.brandPrimary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.contrast,
                title: 'Appearance',
                subtitle: 'Light or high contrast display',
                status: AppearanceSettings.instance.value == 'highContrast'
                    ? 'High contrast'
                    : 'Light',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppearancePage(),
                  ),
                ),
                color: AppColors.textSecondary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'Choose your preferred language',
                status: AppLanguage.instance.code == 'hi'
                    ? 'हिन्दी'
                    : 'English',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LanguagePage()),
                ),
                color: AppColors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text(
            'home',
            'profile.section.support',
            fallback: 'Support & Education',
          ),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.help_outline,
                title: _appContent.text(
                  'home',
                  'profile.tile.help.title',
                  fallback: 'Help & Support',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.tile.help.subtitle',
                  fallback: 'FAQs, contact support and raise a ticket',
                ),
                onTap: () => unawaited(
                  showSupportChatPanel(
                    context,
                    initialMessage: _appContent.text(
                      'support',
                      'chat_preset.help',
                      fallback: 'Hello, I need help with my account.',
                    ),
                  ),
                ),
                color: AppColors.brandPrimary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.menu_book_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.insights.title',
                  fallback: 'Wealth Insights',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.tile.insights.subtitle',
                  fallback: 'Knowledge for informed investment decisions',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WealthInsightsPage(),
                  ),
                ),
                color: AppColors.gain,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl - 2),
        AppText(
          _appContent.text('home', 'profile.section.legal', fallback: 'Legal'),
          style: AppTypography.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Card(
          color: AppColors.surface,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.info_outline_rounded,
                title: _appContent.text(
                  'home',
                  'profile.tile.about.title',
                  fallback: 'About Us',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.tile.about.subtitle',
                  fallback: 'About our app, terms and policies',
                ),
                onTap: _openAbout,
                color: AppColors.brandPrimary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.description_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.terms.title',
                  fallback: 'Terms & Conditions',
                ),
                subtitle: '',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(title: 'Terms'),
                  ),
                ),
                color: AppColors.textSecondary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.privacy_tip_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.privacy.title',
                  fallback: 'Privacy Policy',
                ),
                subtitle: '',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(title: 'Privacy'),
                  ),
                ),
                color: AppColors.textSecondary,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.logout_rounded,
                title: _appContent.text(
                  'home',
                  'profile.logout_label',
                  fallback: 'Logout',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.logout_subtitle',
                  fallback: 'Securely logout from your account',
                ),
                onTap: _confirmSignOut,
                color: AppColors.loss,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md + 2),
        AppText(
          AppConfig.appName,
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      ],
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? status,
    VoidCallback? onTap,
    Color color = AppColors.brandDark,
  }) {
    return ListTile(
      minTileHeight: 44,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 0,
      ),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: AppRadius.borderSm,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: AppText(
        title,
        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : AppText(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
      trailing: onTap == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status != null) ...[
                  AppText(
                    status,
                    style: AppTypography.caption.copyWith(
                      color: status == 'Verified'
                          ? AppColors.gain
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs + 1),
                ],
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
      onTap: onTap,
    );
  }

  Widget _profileStatusPill({
    required IconData icon,
    required String label,
    Color iconColor = Colors.white70,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 12),
          const SizedBox(width: 4),
          AppText(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    _openAccountSettings('profile');
  }

  Future<void> _openAccountSettings(String section) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountSettingsPage(section: section),
      ),
    );
    if (!mounted) return;
    if (changed == true || section == 'profile') {
      final session = await AuthService().restoreSession();
      if (!mounted) return;
      setState(() {
        accountName = session?.fullName.isNotEmpty == true
            ? session!.fullName
            : accountName;
      });
    }
    if (section == 'kyc' && accountPhone.isNotEmpty) {
      final refreshedStatus = await AuthService().fetchKycStatus();
      if (mounted) setState(() => kycStatus = refreshedStatus);
    }
  }

  void _openAbout() {
    final company = _appContent.text(
      'about',
      'company_name',
      fallback: AppConfig.appName,
    );
    final version = _appContent.text(
      'about',
      'app_version',
      fallback: 'Version 1.0.0',
    );
    final legalName = _appContent.text('about', 'legal_name');
    final address = _appContent.text('about', 'registered_address');
    final grievance = _appContent.text('about', 'grievance_contact');
    final summary = _appContent.text('about', 'summary');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  company,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                AppText(version),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppText(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
                if (legalName.isNotEmpty ||
                    address.isNotEmpty ||
                    grievance.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  if (legalName.isNotEmpty)
                    AppText(
                      legalName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(address),
                  ],
                  if (grievance.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(grievance),
                  ],
                ],
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const AppText('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Terms'),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const AppText('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Privacy'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Sign out?'),
        content: const AppText(
          'Your account data is saved on this '
          'device and will be restored after '
          'you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              await AuthService().clearSession();

              if (!mounted) {
                return;
              }

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LoginPage(
                    onSignedIn: (_) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const MarketHomePage(),
                        ),
                      );
                    },
                  ),
                ),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const AppText('Sign Out'),
          ),
        ],
      ),
    );
  }
}
