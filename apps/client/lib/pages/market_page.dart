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
  List<double> _portfolioSeries = const <double>[];
  bool _portfolioHistoryLoading = false;
  int _portfolioHistoryRequest = 0;
  bool _amountsHidden = false;
  double? _periodProfit;
  String? _historyFrom;
  String? _historyError;
  Map<String, dynamic> _profileData = {};
  DeviceBiometric? _biometricCapability;
  bool _biometricEnabled = false;
  bool _biometricBusy = false;
  bool _signingOut = false;
  bool isLoading = true;
  bool _accountSnapshotLoaded = false;
  bool _accountSnapshotFailed = false;
  bool _accountSnapshotRefreshing = true;
  Future<void>? _accountRefreshInFlight;
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
    unawaited(_loadHomeOpsContent());
  }

  Future<void> _loadHomeOpsContent() async {
    final results = await Future.wait<dynamic>([
      AnnouncementsService.instance.list(),
      FeaturedInstrumentsService.instance.homeFeatured(),
    ]);
    if (!mounted) return;
    final announcements = results[0] as List<AnnouncementItem>;
    final featured = results[1] as List<StockQuote>;
    setState(() {
      _homeAnnouncement = pickTopAnnouncement(announcements);
      _homeFeatured
        ..clear()
        ..addAll(featured);
    });
    if (!_optionalUpdatePrompted) {
      _optionalUpdatePrompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(maybeShowOptionalUpdateDialog(context));
      });
    }
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
    if (!mounted) return;
    final openTime = status?['openTime']?.toString();
    final closeTime = status?['closeTime']?.toString();
    setState(() {
      marketOpen = status?['isOpen'] is bool ? status!['isOpen'] as bool : null;
      if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
        marketHours = '$openTime - $closeTime IST';
      }
    });
  }

  Future<void> _refreshAccountSnapshot() async {
    final active = _accountRefreshInFlight;
    if (active != null) return active;
    final refresh = _performAccountRefresh();
    _accountRefreshInFlight = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_accountRefreshInFlight, refresh)) {
        _accountRefreshInFlight = null;
      }
    }
  }

  Future<void> _performAccountRefresh() async {
    if (!mounted) return;
    setState(() => _accountSnapshotRefreshing = true);
    try {
      final snapshot = await tradingService.fetchAccountSnapshot(
        allowCached: false,
      );
      if (!mounted) return;
      if (snapshot == null) throw StateError('Account snapshot unavailable');
      setState(() {
        _accountSnapshotLoaded = true;
        _accountSnapshotFailed = false;
        _applyAccountSnapshot(snapshot);
      });
    } catch (_) {
      if (mounted) setState(() => _accountSnapshotFailed = true);
    } finally {
      if (mounted) setState(() => _accountSnapshotRefreshing = false);
    }
  }

  Future<void> _refreshMarketData() async {
    final active = _marketRefreshInFlight;
    if (active != null) return active;
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
      _loadHomeIndexHistory(),
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
      marketOpen = session?['isOpen'] is bool
          ? session!['isOpen'] as bool
          : null;
      if (session != null) {
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

  Future<void> _loadDashboardSection(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {
      // Each endpoint loads independently, preserving other confirmed data.
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadAppData() async {
    try {
      final session = await AuthService().restoreSession();
      if (!mounted) return;
      setState(() {
        accountName = session?.fullName.isNotEmpty == true
            ? session!.fullName
            : 'Client';
        accountPhone = session?.phone ?? '';
        accountNumber = session?.accountNumber ?? '';
      });
    } catch (_) {
      // Authentication recovery is handled by the session-expiry flow.
    }
    if (!mounted) return;
    await Future.wait<void>([
      _refreshAccountSnapshot(),
      _loadDashboardSection(() async {
        if (accountPhone.isNotEmpty) {
          kycStatus = await AuthService().fetchKycStatus();
        }
      }),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchSnapshot();
        if (remote.isNotEmpty) {
          stocks
            ..clear()
            ..addAll(remote);
        }
      }),
      _loadDashboardSection(() async {
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
      }),
      _loadDashboardSection(_refreshMarketSession),
      _loadDashboardSection(() async {
        final remote = await tradingService.fetchOrders();
        orders
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchInstitutionalOffers();
        institutionalStocks
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        final remote = await AuthService().fetchWithdrawals();
        withdrawalRequests
          ..clear()
          ..addAll(remote);
      }),
      _loadDashboardSection(() async {
        try {
          final remote = await ipoService.fetchOpenIpos();
          ipos
            ..clear()
            ..addAll(remote);
          _iposFailed = false;
        } catch (_) {
          _iposFailed = true;
          rethrow;
        }
      }),
      _loadDashboardSection(() async {
        try {
          final remote = await ipoService.fetchMyApplications();
          ipoApplications
            ..clear()
            ..addAll(remote);
          _ipoApplicationsFailed = false;
        } catch (_) {
          _ipoApplicationsFailed = true;
          rethrow;
        }
      }),
      _loadDashboardSection(() async {
        final profile = await ClientAccountService().profile();
        _profileData = profile;
        final avatar = profile['avatarData'];
        profileAvatarBytes = avatar is String && avatar.isNotEmpty
            ? base64Decode(avatar)
            : null;
        accountName = profile['fullName']?.toString() ?? accountName;
        accountPhone = profile['phone']?.toString() ?? accountPhone;
        accountNumber =
            profile['account']?['accountNumber']?.toString() ?? accountNumber;
      }),
      _loadDashboardSection(() async {
        final settings = await ClientAccountService().preferences();
        await AppLanguage.instance.select(
          settings['language']?.toString() ?? 'en',
        );
        await _loadAppContent(force: true);
        await AppearanceSettings.instance.select(
          settings['theme']?.toString() ?? 'light',
        );
      }),
      _loadDashboardSection(_refreshUnreadNotificationCount),
      _loadDashboardSection(() async {
        final remote = await marketDataService.fetchMarketNews();
        if (remote.isNotEmpty) {
          marketNews
            ..clear()
            ..addAll(remote);
        }
      }),
    ]);
    if (!mounted) return;
    setState(() => isLoading = false);
    unawaited(_loadPortfolioHistory(_portfolioPeriod));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && selectedIndex == 0) _showPendingIpoAllocationIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
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
                  height: AppSpacing.navHeight,
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
                      icon: const Icon(Icons.business_center_outlined),
                      selectedIcon: const Icon(
                        Icons.business_center,
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

  void _onDestinationSelected(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _previousSelectedIndex = selectedIndex;
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
      unawaited(_loadBiometricSettings());
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

  Future<void> _loadBiometricSettings() async {
    final capability = await DeviceBiometrics.available();
    var enabled = false;
    if (capability != null) {
      final token = await AuthService().restoreBiometricToken();
      enabled = token != null && token.isNotEmpty;
    }
    if (!mounted) return;
    setState(() {
      _biometricCapability = capability;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometricQuickLogin(bool enable) async {
    if (_biometricBusy || _biometricCapability == null) return;
    setState(() => _biometricBusy = true);
    try {
      if (enable) {
        final verified = await LocalAuthentication().authenticate(
          localizedReason: 'Enable biometric quick login',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!verified) return;
        await AuthService().enableBiometricQuickLogin();
        if (mounted) setState(() => _biometricEnabled = true);
      } else {
        await AuthService().disableBiometricQuickLogin();
        if (mounted) setState(() => _biometricEnabled = false);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            clientErrorMessage(
              error,
              fallback: enable
                  ? 'Unable to enable biometric quick login'
                  : 'Unable to disable biometric quick login',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
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
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        );

      case 2:
        return TradingCenterPage(
          stocks: stocks,
          positions: positions,
          orders: orders,
          institutionalStocks: institutionalStocks,
          ipos: ipos,
          ipoApplications: ipoApplications,
          iposFailed: _iposFailed,
          ipoApplicationsFailed: _ipoApplicationsFailed,
          onRetryIpos: () async {
            await Future.wait([
              _loadDashboardSection(() async {
                try {
                  final remote = await ipoService.fetchOpenIpos();
                  ipos
                    ..clear()
                    ..addAll(remote);
                  _iposFailed = false;
                } catch (_) {
                  _iposFailed = true;
                  rethrow;
                }
              }),
              _loadDashboardSection(() async {
                try {
                  final remote = await ipoService.fetchMyApplications();
                  ipoApplications
                    ..clear()
                    ..addAll(remote);
                  _ipoApplicationsFailed = false;
                } catch (_) {
                  _ipoApplicationsFailed = true;
                  rethrow;
                }
              }),
            ]);
          },
          onTrade: _openStock,
          onApplyIpo: _applyIpo,
          onAlertsTap: _openNotifications,
          notificationCount: unreadNotificationCount,
          indexQuotes: indexQuotes,
          onViewMarkets: () => _onDestinationSelected(1),
          onOpenOrderTicket: _openStockForTrade,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        );

      case 3:
        return _portfolioBody();

      case 4:
        return _accountBody();

      default:
        return _marketBody();
    }
  }

  String _balanceText(double value, {bool signed = false}) {
    if (_amountsHidden) return '******';
    if (!_accountSnapshotLoaded) return '--';
    return signed ? formatSignedPrice(value) : formatPrice(value);
  }

  Widget _accountDataStatus() => AccountDataStatus(
    hasData: _accountSnapshotLoaded,
    refreshing: _accountSnapshotRefreshing,
    failed: _accountSnapshotFailed,
    onRetry: () => unawaited(_refreshAccountSnapshot()),
  );

  Widget _companyShowcaseCard(CompanyShowcase company) {
    return AppCard(
      radius: AppRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimarySoft,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: company.logoUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: AppRadius.borderSm,
                        child: Image.network(
                          company.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.business_rounded,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.business_rounded,
                        color: AppColors.brandPrimary,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      company.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (company.videoUrl?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => launchUrl(Uri.parse(company.videoUrl!)),
              borderRadius: AppRadius.borderSm,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        color: AppColors.brandPrimary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppText(
                        _appContent.text(
                          'home',
                          'company.video_cta',
                          fallback: 'Watch our company introduction',
                        ),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppText(
            company.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(height: 1.45),
          ),
          if (company.websiteUrl?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(company.websiteUrl!)),
                child: AppText(
                  _appContent.text(
                    'home',
                    'company.website_cta',
                    fallback: 'Visit website',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDepositSupport() {
    // APP Add Funds opens the in-app Deposit page (not the side Support button).
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DepositPage()));
  }

  Future<void> _openWithdrawalRequest() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WithdrawalPage(
          availableBalance: availableBalance,
          frozenBalance: frozenBalance,
          accountName: accountName,
          onFundsUpdated: (request, snapshot) {
            if (!mounted) return;
            setState(() {
              withdrawalRequests.removeWhere((item) => item.id == request.id);
              withdrawalRequests.insert(0, request);
              if (snapshot != null) {
                _applyAccountSnapshot(snapshot, positions: false);
              } else {
                buyingPower = math
                    .max(0, buyingPower - request.amount)
                    .toDouble();
                frozenBalance += request.amount;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _marketBody() {
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
    final localTotalPortfolioValue = cashBalance + holdingsValue;
    final localUnrealizedPnl = positions.values.fold<double>(0, (
      total,
      position,
    ) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      return total +
          position.unrealizedProfitLoss(stock?.price ?? position.averageCost);
    });
    final totalPortfolioValue =
        _authoritativeTotalAsset ?? localTotalPortfolioValue;
    final todayPnl = localUnrealizedPnl;
    final unrealizedPnl = _authoritativeUnrealizedPnl ?? localUnrealizedPnl;
    final vix =
        indexQuotes['INDIAVIX'] ??
        indexQuotes['INDIA VIX'] ??
        indexQuotes['VIX'];
    final quotes = latestQuoteUpdatedAt(stocks);
    final stale = quotesAreStale(stocks) || !marketConnected;
    return Container(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _refreshMarketData(),
            _refreshAccountSnapshot(),
            _reloadNews(),
          ]);
        },
        child: HomeDashboard(
          accountName: accountName,
          avatarBytes: profileAvatarBytes,
          onAvatarTap: () => unawaited(_pickProfileAvatar()),
          onSearch: _openStockSearch,
          onNotifications: () => unawaited(_openNotifications()),
          notificationCount: unreadNotificationCount,
          totalAssets: totalPortfolioValue,
          availableFunds: availableBalance,
          frozenFunds: frozenBalance,
          todayPnl: todayPnl,
          unrealizedPnl: unrealizedPnl,
          accountLoaded: _accountSnapshotLoaded,
          accountFailed: _accountSnapshotFailed,
          accountRefreshing: _accountSnapshotRefreshing,
          quotesLoading: isLoading,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
          hideBalances: _amountsHidden,
          onToggleHideBalances: () =>
              setState(() => _amountsHidden = !_amountsHidden),
          periodProfit: _periodProfit,
          periodLabel: _portfolioPeriod,
          periodLoading: _portfolioHistoryLoading,
          historyError: _historyError,
          historyFrom: _historyFrom,
          portfolioSeries: _portfolioSeries,
          outstandingIpo: outstandingIpo,
          onSelectPeriod: (period) => unawaited(_loadPortfolioHistory(period)),
          indices: [
            HomeIndexQuote(
              label: 'NIFTY 50',
              price: nifty50Price,
              changePercent: nifty50Change,
              history: indexHistory['NIFTY 50'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'SENSEX',
              price: sensexPrice,
              changePercent: sensexChange,
              history: indexHistory['SENSEX'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'BANK NIFTY',
              price: bankNiftyPrice,
              changePercent: bankNiftyChange,
              history: indexHistory['BANK NIFTY'] ?? const <double>[],
            ),
            HomeIndexQuote(
              label: 'INDIA VIX',
              price: vix?.$1 ?? 0,
              changePercent: vix?.$2 ?? 0,
              history: indexHistory['INDIA VIX'] ?? const <double>[],
            ),
          ],
          gainers: homeTopMovers(stocks, gainers: true),
          losers: homeTopMovers(stocks, gainers: false),
          news: List<MarketNewsItem>.from(marketNews),
          featured: _homeFeatured,
          quoteUpdatedAt: quotes,
          quotesStale: stale,
          kycStatus: kycStatus,
          kycAvailable: !isLoading && accountPhone.isNotEmpty,
          onOpenKyc: () => unawaited(_openAccountSettings('kyc')),
          onDeposit: _openDepositSupport,
          onWithdraw: () => unawaited(_openWithdrawalRequest()),
          onTrade: () => _onDestinationSelected(2),
          onRetryAccount: () => unawaited(_refreshAccountSnapshot()),
          onRetryNews: () => unawaited(_reloadNews()),
          onRetryQuotes: () => unawaited(_refreshMarketData()),
          onOpenMarkets: () => _onDestinationSelected(1),
          onOpenNews: (item) => unawaited(_openNews(item)),
          onOpenStock: _openStock,
          onOpenIndex: _openHomeIndex,
          onViewAllNews: marketNews.isEmpty
              ? null
              : () => unawaited(_openAllMarketNews()),
          announcement: _homeAnnouncement == null
              ? null
              : HomeAnnouncementBanner(item: _homeAnnouncement!),
          companyCard: companyShowcases.isEmpty
              ? null
              : _companyShowcaseCard(companyShowcases.first),
          bottomPadding: SupportUiMetrics.of(context).fabBottom + AppSpacing.lg,
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

  Widget _notificationButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: unreadNotificationCount > 0
              ? 'Notifications ($unreadNotificationCount unread)'
              : 'Notifications',
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

  void _openHomeIndex(HomeIndexQuote item) {
    final ref =
        MarketIndexRef.byLabel(item.label) ??
        MarketIndexRef(
          label: item.label,
          symbol: item.label.replaceAll(' ', ''),
          exchange: 'NSE',
          venue: 'NSE',
        );
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => IndexDetailPage(
          quote: MarketIndexQuote(
            ref: ref,
            price: item.price,
            changePercent: item.changePercent,
            history: item.history,
          ),
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        ),
      ),
    );
  }

  void _openStock(StockQuote stock) {
    _openStockForTrade(stock, isBuy: true);
  }

  void _openStockForTrade(StockQuote stock, {required bool isBuy}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StockDetailPage(
          stock: stock,
          onOrderPlaced: _placeOrder,
          initialIsBuy: isBuy,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        ),
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
          _applyAccountSnapshot(snapshot);
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
    onExplore: () => _onDestinationSelected(2),
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
    return ProfileIdentityHeader(
      name: accountName,
      accountNumber: accountNumber,
      phone: accountPhone,
      kycStatus: kycStatus,
      clientTier: _profileData['clientTier']?.toString() ?? '--',
      memberSince:
          _profileData['createdAt']?.toString().split('T').first ?? '--',
      accountStatus: _profileData['status']?.toString() ?? '--',
      avatarBytes: profileAvatarBytes,
      onAvatarTap: _pickProfileAvatar,
      onEdit: _editProfile,
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
    return AppFadeIn(
      switchKey: 'profile|$accountNumber|$kycStatus|${_profileData['status']}',
      child: ListView(
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
              IconButton(
                tooltip: 'Search stocks',
                onPressed: _openStockSearch,
                icon: const Icon(Icons.search_rounded, size: 22),
              ),
              _notificationButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          _profileHeader(),
          const SizedBox(height: AppSpacing.lg),
          AppText(
            _appContent.text(
              'home',
              'profile.section.overview',
              fallback: 'Account Overview',
            ),
            style: AppUi.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          _accountDataStatus(),
          AppCard(
            radius: AppRadius.md,
            child: AccountMetrics(
              items: [
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.available',
                    fallback: 'Available Balance',
                  ),
                  _balanceText(availableBalance),
                ),
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.portfolio',
                    fallback: 'Product Holdings',
                  ),
                  _balanceText(productValue),
                ),
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.returns',
                    fallback: 'Total Returns',
                  ),
                  _balanceText(totalReturns, signed: true),
                  color: _amountsHidden || !_accountSnapshotLoaded
                      ? AppColors.textPrimary
                      : totalReturns >= 0
                      ? AppColors.gain
                      : AppColors.loss,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.account',
              fallback: 'Account',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: 'Account ID and full name',
                onTap: _editProfile,
                color: AppColors.brandPrimary,
              ),
              ProfileMenuRow(
                icon: Icons.verified_user_outlined,
                title: 'KYC Verification',
                subtitle: 'Identity documents and review status',
                status: profileKycLabel(kycStatus),
                statusColor: kycStatus == 'APPROVED'
                    ? AppColors.gain
                    : kycStatus == 'REJECTED'
                    ? AppColors.loss
                    : AppColors.warning,
                onTap: () => _openAccountSettings('kyc'),
                color: AppColors.gain,
              ),
              ProfileMenuRow(
                icon: Icons.account_balance_outlined,
                title: 'Bank Accounts',
                subtitle: 'Linked bank account for withdrawals',
                onTap: () => _openAccountSettings('banks'),
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.funds',
              fallback: 'Funds',
            ),
            children: [
              ProfileMenuRow(
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
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.security',
              fallback: 'Security',
            ),
            children: [
              ProfileMenuRow(
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
              ProfileMenuRow(
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
              ProfileMenuRow(
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
              if (_biometricCapability != null)
                ProfileMenuRow(
                  icon: _biometricCapability == DeviceBiometric.face
                      ? Icons.face_retouching_natural_outlined
                      : Icons.fingerprint,
                  title: 'Biometric quick login',
                  subtitle: _biometricCapability == DeviceBiometric.face
                      ? 'Face ID'
                      : 'Fingerprint',
                  color: AppColors.info,
                  trailing: Switch.adaptive(
                    value: _biometricEnabled,
                    onChanged: _biometricBusy ? null : _setBiometricQuickLogin,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.preferences',
              fallback: 'Preferences',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.notifications_none_rounded,
                title: 'Alert Preferences',
                subtitle: 'Choose which account updates you receive',
                onTap: () => _openAccountSettings('preferences'),
                color: AppColors.brandPrimary,
              ),
              ProfileMenuRow(
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
              ProfileMenuRow(
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
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.support',
              fallback: 'Support & Education',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.help_outline,
                title: _appContent.text(
                  'home',
                  'profile.tile.help.title',
                  fallback: 'Help & Support',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.tile.help.subtitle',
                  fallback: 'FAQs and contact support',
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
              ProfileMenuRow(
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
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.legal',
              fallback: 'Legal',
            ),
            children: [
              ProfileMenuRow(
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
              ProfileMenuRow(
                icon: Icons.description_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.terms.title',
                  fallback: 'Terms & Conditions',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(title: 'Terms'),
                  ),
                ),
                color: AppColors.textSecondary,
              ),
              ProfileMenuRow(
                icon: Icons.privacy_tip_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.privacy.title',
                  fallback: 'Privacy Policy',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(title: 'Privacy'),
                  ),
                ),
                color: AppColors.textSecondary,
              ),
              ProfileMenuRow(
                icon: Icons.warning_amber_rounded,
                title: _appContent.text(
                  'home',
                  'profile.tile.risk.title',
                  fallback: 'Risk Disclosure',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalPage(title: 'Risk Disclosure'),
                  ),
                ),
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppCard(
            padding: EdgeInsets.zero,
            child: ProfileMenuRow(
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
              destructive: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppText(
            AppConfig.appName,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
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
    final marketingVersion = _appContent.text('about', 'app_version');
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
                AppText('App version ${AppConfig.appVersion}'),
                if (marketingVersion.isNotEmpty &&
                    marketingVersion != 'Version ${AppConfig.appVersion}' &&
                    marketingVersion != AppConfig.appVersion) ...[
                  const SizedBox(height: 4),
                  AppText(
                    marketingVersion,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const AppText('Risk Disclosure'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const LegalPage(title: 'Risk Disclosure'),
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
    if (_signingOut) return;
    var started = false;
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
              if (started) return;
              Navigator.pop(dialogContext);
            },
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (started || _signingOut) return;
              started = true;
              setState(() => _signingOut = true);
              Navigator.pop(dialogContext);
              await AuthService().clearSession();
              if (!mounted) return;
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
