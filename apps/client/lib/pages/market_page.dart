import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_config.dart';
import '../models/institutional_opportunity.dart';
import '../models/ipo.dart';
import '../models/market_news_item.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../models/withdrawal_request.dart';
import '../services/auth_service.dart';
import '../services/client_account_service.dart';
import '../services/ipo_service.dart';
import '../services/market_data_service.dart';
import '../services/market_socket_service.dart';
import '../services/trading_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/market_header.dart';
import '../widgets/stock_logo.dart';
import 'login_page.dart';
import 'markets_page.dart';
import 'market_news_page.dart';
import 'notifications_page.dart';
import 'account_settings_page.dart';
import 'account_content_page.dart';
import 'legal_page.dart';
import 'stock_detail_page.dart';
import 'stock_search_page.dart';
import 'support_chat_page.dart';
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

class _MarketHomePageState extends State<MarketHomePage> {
  static const double _minimumWithdrawalAmount = 100;
  int selectedIndex = 0;
  String _portfolioPeriod = '1D';
  List<double> _portfolioSeries = const <double>[];
  bool _portfolioHistoryLoading = false;
  bool isLoading = true;
  bool _ipoAllocationDialogOpen = false;
  bool _withdrawalSubmitting = false;
  bool marketConnected = false;
  bool? marketOpen;
  int unreadNotificationCount = 0;
  String marketHours = '09:15 - 15:30 IST';
  Timer? _marketSessionTimer;
  Timer? _marketNewsTimer;

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

  final List<PendingOrder> pendingOrders = <PendingOrder>[];

  final List<WithdrawalRequest> withdrawalRequests = <WithdrawalRequest>[];

  final List<InstitutionalStock> institutionalStocks = <InstitutionalStock>[];

  final List<Ipo> ipos = <Ipo>[];

  final List<IpoApplication> ipoApplications = <IpoApplication>[];

  final Map<String, PortfolioPosition> positions =
      <String, PortfolioPosition>{};

  final List<StockQuote> stocks = <StockQuote>[];
  final List<MarketNewsItem> marketNews = <MarketNewsItem>[];
  final Map<String, List<double>> stockHistory = <String, List<double>>{};
  final Map<String, List<double>> indexHistory = <String, List<double>>{};

  Future<void> _applyIpo(Ipo ipo) async {
    final applicationCount = ipoApplications
        .where((application) => application.ipoId == ipo.id)
        .length;

    if (applicationCount >= 5) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum of 5 applications allowed for this IPO'),
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
          content: Text(
            '${ipo.companyName} application ${applicationCount + 1} of 5 submitted',
          ),
        ),
      );
    } on IpoException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showPendingIpoAllocationIfNeeded() {
    if (!mounted || _ipoAllocationDialogOpen) {
      return;
    }

    IpoApplication? pendingApplication;

    for (final application in ipoApplications) {
      if (application.status == IpoApplicationStatus.allocated &&
          application.allocatedQuantity > 0 &&
          application.remainingAmount > 0) {
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

    if (application.status != IpoApplicationStatus.allocated ||
        application.allocatedQuantity <= 0 ||
        application.remainingAmount <= 0) {
      return;
    }

    _ipoAllocationDialogOpen = true;

    final totalSubscriptionAmount =
        application.allocatedQuantity * application.subscriptionPrice;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppConfig.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'IPO Allotment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  application.companyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  application.symbol,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'You have received an IPO allotment. '
                    'Please complete the remaining '
                    'subscription amount.',
                    style: TextStyle(height: 1.4),
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
                const Divider(height: 24),
                _ipoDialogValue(
                  'Paid Amount',
                  formatPrice(application.paidAmount),
                  valueColor: AppConfig.gainColor,
                ),
                const Divider(height: 24),
                _ipoDialogValue(
                  'Remaining Amount',
                  formatPrice(application.remainingAmount),
                  valueColor: AppConfig.lossColor,
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    _ipoAllocationDialogOpen = false;
  }

  Widget _ipoDialogValue(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Text(
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

    marketConnected = marketSocket.isConnected;
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

  Future<void> _refreshMarketData() async {
    final results = await Future.wait<dynamic>([
      marketDataService.fetchSnapshot(),
      marketDataService.fetchIndexSnapshot(),
      marketDataService.fetchMarketSession(),
      marketDataService.fetchInstitutionalOffers(),
      marketDataService.fetchMarketNews(),
    ]);
    if (!mounted) return;
    final refreshedStocks = results[0] as List<StockQuote>;
    final indices = results[1] as List<Map<String, dynamic>>;
    final session = results[2] as Map<String, dynamic>?;
    final refreshedInstitutional = results[3] as List<InstitutionalStock>;
    final refreshedNews = results[4] as List<MarketNewsItem>;
    setState(() {
      if (refreshedStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(refreshedStocks);
      }
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
    _marketSessionTimer?.cancel();
    _marketNewsTimer?.cancel();
    marketSocket.removeConnectionListener(_handleMarketConnection);
    marketSocket.dispose();
    super.dispose();
  }

  Future<void> _loadAppData() async {
    final session = await AuthService().restoreSession();
    final preferences = await SharedPreferences.getInstance();
    final savedAvatar = preferences.getString('profile_avatar_base64');

    accountName = session?.fullName.isNotEmpty == true
        ? session!.fullName
        : 'Client';
    accountPhone = session?.phone ?? '';
    accountNumber = session?.accountNumber ?? '';
    if (accountPhone.isNotEmpty) {
      kycStatus = await AuthService().fetchKycStatus();
    }
    if (savedAvatar?.isNotEmpty == true) {
      profileAvatarBytes = base64Decode(savedAvatar!);
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

    final sessionStatus = await marketDataService.fetchMarketSession();
    if (sessionStatus != null) {
      marketOpen = sessionStatus['isOpen'] == true;
      final openTime = sessionStatus['openTime']?.toString();
      final closeTime = sessionStatus['closeTime']?.toString();
      if (openTime?.isNotEmpty == true && closeTime?.isNotEmpty == true) {
        marketHours = '$openTime - $closeTime IST';
      }
    }

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
    } catch (_) {
      cashBalance = 0;
      buyingPower = 0;
      frozenBalance = 0;
      realizedProfitLoss = 0;
      positions.clear();
    }

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
      final notifications = await ClientAccountService().notifications();
      unreadNotificationCount = notifications
          .where((item) => item['readAt'] == null)
          .length;
    } catch (_) {
      unreadNotificationCount = 0;
    }

    final latestNews = await marketDataService.fetchMarketNews();
    if (latestNews.isNotEmpty) {
      marketNews
        ..clear()
        ..addAll(latestNews);
    }

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
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _selectedBody(),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 96,
                  child: SafeArea(child: _sideCustomerServiceButton()),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppConfig.borderColor)),
          ),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  fontSize: MediaQuery.sizeOf(context).width < 360 ? 10 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 24)),
            ),
            child: NavigationBar(
              height: MediaQuery.sizeOf(context).height < 650 ? 66 : 72,
              elevation: 0,
              backgroundColor: Colors.white,
              indicatorColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });

                if (index == 3) {
                  unawaited(_loadPortfolioHistory(_portfolioPeriod));
                }

                if (index == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) {
                      return;
                    }

                    _showPendingIpoAllocationIfNeeded();
                  });
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home, color: AppConfig.primaryColor),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(
                    Icons.bar_chart,
                    color: AppConfig.primaryColor,
                  ),
                  label: 'Markets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_horiz_rounded),
                  selectedIcon: Icon(
                    Icons.swap_horiz_rounded,
                    color: AppConfig.primaryColor,
                  ),
                  label: 'Trading',
                ),
                NavigationDestination(
                  icon: Icon(Icons.business_center_outlined),
                  selectedIcon: Icon(
                    Icons.business_center,
                    color: AppConfig.primaryColor,
                  ),
                  label: 'Portfolio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(
                    Icons.person,
                    color: AppConfig.primaryColor,
                  ),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          pendingOrders: pendingOrders,
          institutionalStocks: institutionalStocks,
          ipos: ipos,
          ipoApplications: ipoApplications,
          onTrade: _openStock,
          onApplyIpo: _applyIpo,
          onAlertsTap: _openNotifications,
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppConfig.primaryDarkColor,
                AppConfig.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0878F9),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Text(
                          'Total Portfolio Value',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.visibility_outlined,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1D',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      formatPrice(totalPortfolioValue),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    height: 54,
                    child: _portfolioSeries.length >= 2
                        ? CustomPaint(
                            painter: _MiniLineChartPainter(
                              color: AppConfig.chartGainColor,
                              values: _portfolioSeries,
                            ),
                          )
                        : const Center(
                            child: Text(
                              '--',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${pnlPositive ? '+' : '-'}${formatPrice(todayPnl.abs())} Today',
                style: TextStyle(
                  color: pnlPositive
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (outstandingIpo > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'IPO Outstanding ${formatPrice(outstandingIpo)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _homeQuickActions(),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppConfig.borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: _homeBalanceValue(
                  'Available Balance',
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
                  "Today's P&L",
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${value > 0 && label.contains('P&L') ? '+' : ''}${formatPrice(value)}',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
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
          child: _HomeActionButton(
            label: 'Add Money',
            subtitle: 'Instant Deposit',
            icon: Icons.support_agent_outlined,
            color: AppConfig.primaryColor,
            onTap: _openDepositSupport,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HomeActionButton(
            label: 'Withdraw',
            subtitle: 'Withdraw to Bank',
            icon: Icons.account_balance_wallet_outlined,
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        if (onViewAll != null)
          TextButton(onPressed: onViewAll, child: const Text('View All')),
      ],
    );
  }

  Widget _marketOverviewGrid() {
    final vix =
        indexQuotes['INDIAVIX'] ??
        indexQuotes['INDIA VIX'] ??
        indexQuotes['VIX'];
    final indices = [
      (
        'NIFTY 50',
        nifty50Price > 0 ? formatIndex(nifty50Price) : '--',
        nifty50Change,
        'NSE',
      ),
      (
        'SENSEX',
        sensexPrice > 0 ? formatIndex(sensexPrice) : '--',
        sensexChange,
        'BSE',
      ),
      (
        'BANK NIFTY',
        bankNiftyPrice > 0 ? formatIndex(bankNiftyPrice) : '--',
        bankNiftyChange,
        'NSE',
      ),
      (
        'INDIA VIX',
        vix != null && vix.$1 > 0 ? formatIndex(vix.$1) : '--',
        vix?.$2 ?? 0,
        'NSE',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620
            ? 4
            : constraints.maxWidth >= 460
            ? 3
            : 2;
        const gap = 8.0;
        final cardWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: indices.map((item) {
            final positive = item.$3 >= 0;

            return SizedBox(
              width: cardWidth,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE8EDF5)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.$2,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: positive
                            ? AppConfig.gainColor
                            : AppConfig.lossColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      height: 24,
                      width: double.infinity,
                      child: (indexHistory[item.$1]?.length ?? 0) >= 2
                          ? CustomPaint(
                              painter: _MiniLineChartPainter(
                                color: positive
                                    ? AppConfig.gainColor
                                    : AppConfig.lossColor,
                                values: indexHistory[item.$1]!,
                              ),
                            )
                          : const Center(
                              child: Text(
                                '--',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _compactMovers() {
    final gainers = _topMovers(gainers: true);
    final losers = _topMovers(gainers: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
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

  List<StockQuote> _topMovers({required bool gainers}) {
    final movers = stocks
        .where(
          (stock) =>
              stock.price > 0 &&
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
                child: Text(
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
                  child: Text(
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
              child: Text(
                positive
                    ? 'No advancing instruments'
                    : 'No declining instruments',
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
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
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
                          painter: _MiniLineChartPainter(
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
                            child: Text(
                              formatPrice(stock.price),
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
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
    _openSupportChat(
      initialMessage: 'Hello, I would like to add money to my account.',
    );
  }

  void _openSupportChat({String? initialMessage}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupportChatPage(initialMessage: initialMessage),
      ),
    );
  }

  Widget _sideCustomerServiceButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openSupportChat(),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        child: Ink(
          width: 30,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            color: AppConfig.primaryColor,
            borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_rounded, color: Colors.white, size: 16),
              SizedBox(height: 5),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWithdrawalRequest() async {
    if (_withdrawalSubmitting) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A withdrawal request is being submitted'),
        ),
      );
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
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
          const SnackBar(
            content: Text(
              'Complete your bank account details before withdrawing',
            ),
          ),
        );
      }
      await _openAccountSettings('banks');
      return;
    }
    final amountController = TextEditingController();

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
              title: const Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppConfig.primaryColor,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Withdrawal Request',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatPrice(availableWithdrawalBalance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total frozen: ${formatPrice(frozenBalance)}',
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
                        labelText: 'Withdrawal Amount',
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Minimum withdrawal: ₹100',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 20,
                                color: AppConfig.primaryColor,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Withdrawal Bank Account',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            initialValue: selectedBank['id']?.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Bank account',
                            ),
                            items: bankAccounts.map((bank) {
                              final number =
                                  bank['accountNumber']?.toString() ?? '';
                              final suffix = number.length > 4
                                  ? number.substring(number.length - 4)
                                  : number;
                              return DropdownMenuItem(
                                value: bank['id']?.toString(),
                                child: Text('${bank['bankName']} ••••$suffix'),
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
                            'Account Holder',
                            selectedBank['accountHolder']?.toString() ??
                                accountName,
                          ),
                          const SizedBox(height: 10),
                          _withdrawBankRow(
                            'Bank Account',
                            selectedBank['accountNumber']?.toString() ?? '',
                          ),
                          const SizedBox(height: 10),
                          _withdrawBankRow(
                            'Bank Status',
                            selectedBank['status']?.toString() ?? 'Added',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Your withdrawal request will be submitted for review. '
                      'The requested amount is frozen immediately. Approval '
                      'deducts it from your cash balance; rejection releases it.',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Withdrawal Records',
                            style: TextStyle(
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
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          },
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    if (withdrawalRequests.isEmpty)
                      const Text(
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
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final amount = double.tryParse(
                      amountController.text.trim().replaceAll(',', ''),
                    );

                    if (amount == null || amount < _minimumWithdrawalAmount) {
                      setDialogState(() {
                        errorText = 'Minimum withdrawal amount is ₹100';
                      });
                      return;
                    }

                    if (amount > availableWithdrawalBalance) {
                      setDialogState(() {
                        errorText =
                            'Maximum available: ${formatPrice(availableWithdrawalBalance)}';
                      });
                      return;
                    }

                    if ((selectedBank['accountNumber']?.toString().trim() ?? '')
                            .isEmpty ||
                        (selectedBank['ifscCode']?.toString().trim() ?? '')
                            .isEmpty) {
                      setDialogState(() {
                        errorText = 'Select a complete bank account';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) {
      amountController.dispose();
      return;
    }

    final amount =
        double.tryParse(amountController.text.trim().replaceAll(',', '')) ?? 0;

    amountController.dispose();

    if (amount < _minimumWithdrawalAmount ||
        amount > availableWithdrawalBalance) {
      return;
    }

    late final WithdrawalRequest request;
    TradingAccountSnapshot? updatedSnapshot;

    setState(() => _withdrawalSubmitting = true);
    try {
      request = await AuthService().submitWithdrawal(
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
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Unable to submit withdrawal. Please try again.'),
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
        content: Text(
          'Withdrawal request ${request.orderNo ?? request.id} submitted. '
          'Funds are now frozen.',
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.orderNo ?? request.id,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                request.statusLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(formatPrice(request.amount))),
              Text(
                '${request.createdAt.day.toString().padLeft(2, '0')}/'
                '${request.createdAt.month.toString().padLeft(2, '0')}/'
                '${request.createdAt.year}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
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
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _openCustomerService({
    required String title,
    required String initialMessage,
    required IconData icon,
  }) {
    final messageController = TextEditingController(text: initialMessage);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEFA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppConfig.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.support_agent,
                        size: 22,
                        color: AppConfig.primaryColor,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You are contacting online customer service inside the app.',
                          style: TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                TextField(
                  controller: messageController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Send a message directly to online customer service. '
                  'Customer service will assist you in this conversation.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final message = messageController.text.trim();

                if (message.isEmpty) {
                  return;
                }

                try {
                  await AuthService().contactSupport(message);

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message sent to online customer service'),
                    ),
                  );
                } on AuthException catch (error) {
                  if (!dialogContext.mounted) return;
                  ScaffoldMessenger.of(dialogContext).hideCurrentSnackBar();
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Send Message'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      messageController.dispose();
    });
  }

  Widget _homeMarketStatus() {
    final color = marketOpen == true
        ? AppConfig.gainColor
        : marketOpen == false
        ? AppConfig.lossColor
        : AppConfig.neutralColor;
    final sessionLabel = marketOpen == true
        ? 'Market Open'
        : marketOpen == false
        ? 'Market Closed'
        : 'Market Status';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '$sessionLabel  •  $marketHours',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            marketConnected ? 'Connected' : 'Reconnecting…',
            style: TextStyle(
              color: marketConnected
                  ? AppConfig.gainColor
                  : AppConfig.neutralColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketBody() {
    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 22.0;
    return Container(
      color: AppConfig.backgroundColor,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          18,
          horizontalPadding,
          28,
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
          const SizedBox(height: 14),
          _homeFundsCard(),
          const SizedBox(height: 18),
          _sectionTitle(
            'Market Indices',
            onViewAll: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 10),
          _marketOverviewGrid(),
          const SizedBox(height: 18),
          _compactMovers(),
          const SizedBox(height: 18),
          _sectionTitle(
            'Market News',
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
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 900,
      maxHeight: 900,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('profile_avatar_base64', base64Encode(bytes));
    if (mounted) setState(() => profileAvatarBytes = bytes);
  }

  Widget _marketNewsSection() {
    if (marketNews.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(Icons.newspaper_outlined, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Live market news is temporarily unavailable.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
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
              .take(6)
              .map(
                (item) => SizedBox(
                  width: width,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openNews(item),
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      height: oneColumn ? 154 : 168,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
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
                                Text(
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
                                Text(
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
        builder: (_) => MarketNewsPage(items: items, onOpen: _openNews),
      ),
    );
  }

  void _showNewsOpenError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Unable to open this news article')),
      );
  }

  Widget _homeTradingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track live markets & place orders on the go',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Invest in equities, Inst., OTC and IPO',
                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Icon(
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
          icon: const Icon(Icons.notifications_none_rounded, size: 28),
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
              child: Text(
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
      final snapshot = await tradingService.fetchAccountSnapshot();
      final remoteOrders = await tradingService.fetchOrders();

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
            ..addAll(
              remoteOrders.isNotEmpty
                  ? remoteOrders
                  : <TradingOrder>[confirmedOrder, ...orders],
            );
        });

        return null;
      }

      setState(() {
        orders
          ..removeWhere(
            (item) => item.clientOrderId == confirmedOrder.clientOrderId,
          )
          ..insert(0, confirmedOrder);
      });

      return null;
    } catch (error) {
      return error.toString();
    }
  }

  // ignore: unused_element
  Widget _ordersBody() {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 72,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Orders yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open a stock and place a Buy or Sell order. It will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  setState(() => selectedIndex = 0);
                },
                icon: const Icon(Icons.show_chart),
                label: const Text('Browse stocks'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Order History',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: _refreshRemoteTradingData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
            ),
          ],
        ),
        Text(
          '${orders.length} order'
          '${orders.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 12),
        ...orders.map(_orderCard),
      ],
    );
  }

  Widget _orderCard(TradingOrder order) {
    final sideColor = order.isBuy ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.isBuy ? 'BUY' : 'SELL',
                    style: TextStyle(
                      color: sideColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.symbol,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Chip(
                  avatar: Icon(Icons.check_circle, size: 18),
                  label: Text('Completed'),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _orderValue('Quantity', '${order.quantity}')),
                Expanded(child: _orderValue('Price', formatPrice(order.price))),
                Expanded(
                  child: _orderValue('Amount', formatPrice(order.amount)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                order.formattedTime,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _refreshRemoteTradingData() async {
    try {
      final snapshot = await tradingService.fetchAccountSnapshot();
      final remoteOrders = await tradingService.fetchOrders();
      if (!mounted) return;
      setState(() {
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
        orders
          ..clear()
          ..addAll(remoteOrders);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trading data refreshed')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Widget _portfolioBody() {
    final positionList = positions.values.where((position) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      return _isSpecialCategory(
        '${position.category} ${stock?.category ?? ''}',
      );
    }).toList()..sort((a, b) => a.symbol.compareTo(b.symbol));

    final holdingsValue = positionList.fold<double>(
      0,
      (total, position) =>
          total +
          position.marketValue(
            _stockFor(position.symbol, exchange: position.exchange).price,
          ),
    );

    final unrealizedProfitLoss = positionList.fold<double>(
      0,
      (total, position) =>
          total +
          position.unrealizedProfitLoss(
            _stockFor(position.symbol, exchange: position.exchange).price,
          ),
    );
    final portfolioRealizedProfitLoss = positionList.fold<double>(
      0,
      (total, position) => total + position.realizedProfitLoss,
    );
    final portfolioTotalProfitLoss =
        unrealizedProfitLoss + portfolioRealizedProfitLoss;

    final totalAssets = cashBalance + holdingsValue;

    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 16.0;
    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 16,
      ),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Portfolio',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: _openStockSearch,
              icon: const Icon(Icons.search_rounded, size: 28),
            ),
            _notificationButton(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                AppConfig.primaryDarkColor,
                AppConfig.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total Portfolio Value',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _portfolioPeriod,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatPrice(totalAssets),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 135,
                    height: 62,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MiniLineChartPainter(
                              color: AppConfig.chartGainColor,
                              values: _portfolioSeries,
                            ),
                          ),
                        ),
                        if (_portfolioHistoryLoading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        if (!_portfolioHistoryLoading &&
                            _portfolioSeries.length < 2)
                          const Text(
                            '--',
                            style: TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                '${portfolioTotalProfitLoss >= 0 ? '+' : '-'}${formatPrice(portfolioTotalProfitLoss.abs())} Overall Returns',
                style: TextStyle(
                  color: portfolioTotalProfitLoss >= 0
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: ['1D', '1W', '1M', '3M', '1Y', 'All']
                    .asMap()
                    .entries
                    .map(
                      (entry) => Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () =>
                              unawaited(_loadPortfolioHistory(entry.value)),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: _portfolioPeriod == entry.value
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                color: _portfolioPeriod == entry.value
                                    ? AppConfig.primaryColor
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Investment Summary',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 420 ? 2 : 4;
                    final itemWidth = constraints.maxWidth / columns;
                    return Wrap(
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _portfolioMetric(
                            'Invested Value',
                            holdingsValue - unrealizedProfitLoss,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _portfolioMetric(
                            'Current Value',
                            holdingsValue,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _portfolioMetric(
                            'Total Returns',
                            portfolioTotalProfitLoss,
                            color: portfolioTotalProfitLoss >= 0
                                ? AppConfig.gainColor
                                : AppConfig.lossColor,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _portfolioMetric(
                            'Available Balance',
                            availableBalance,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _portfolioAllocationCard(positionList),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _profitLossCard(
                'Unrealized P&L',
                unrealizedProfitLoss,
                Icons.trending_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _profitLossCard(
                'Realized P&L',
                portfolioRealizedProfitLoss,
                Icons.task_alt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Top Performers'),
        const SizedBox(height: 10),
        _portfolioTopPerformers(positionList),
        const SizedBox(height: 20),
        _sectionTitle(
          'Recent Activity',
          onViewAll: () => setState(() => selectedIndex = 2),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: orders
                .where((order) {
                  final stock = _stockForOrNull(
                    order.symbol,
                    exchange: order.exchange,
                  );
                  return order.status == 'FILLED' &&
                      _isSpecialCategory(
                        '${order.category} ${stock?.category ?? ''}',
                      );
                })
                .take(5)
                .map(
                  (order) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (order.isBuy
                                  ? AppConfig.gainColor
                                  : AppConfig.lossColor)
                              .withValues(alpha: .12),
                      child: Text(
                        order.isBuy ? 'B' : 'S',
                        style: TextStyle(
                          color: order.isBuy
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(
                      '${order.isBuy ? 'Bought' : 'Sold'} ${order.symbol}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${order.exchange} · ${order.quantity} shares',
                    ),
                    trailing: Text(
                      formatPrice(order.averageFillPrice ?? order.price),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _loadPortfolioHistory(String period) async {
    if (_portfolioHistoryLoading) return;
    final positionList = positions.values.where((position) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      return _isSpecialCategory(
        '${position.category} ${stock?.category ?? ''}',
      );
    }).toList();
    if (positionList.isEmpty) {
      if (mounted) {
        setState(() {
          _portfolioPeriod = period;
          _portfolioSeries = const <double>[];
        });
      }
      return;
    }

    setState(() {
      _portfolioPeriod = period;
      _portfolioHistoryLoading = true;
    });
    try {
      final histories = await Future.wait(
        positionList.map(
          (position) => marketDataService.fetchHistory(
            symbol: position.symbol,
            exchange: position.exchange,
            range: period,
          ),
        ),
      );
      final pointCount = histories.fold<int>(
        0,
        (count, history) => math.max(count, history.data.length),
      );
      final totals = List<double>.filled(pointCount, cashBalance);
      for (
        var historyIndex = 0;
        historyIndex < histories.length;
        historyIndex++
      ) {
        final history = histories[historyIndex];
        final quantity = positionList[historyIndex].quantity.toDouble();
        if (history.data.isEmpty) continue;
        for (var pointIndex = 0; pointIndex < pointCount; pointIndex++) {
          final sourceIndex = pointCount == 1
              ? 0
              : ((history.data.length - 1) * pointIndex / (pointCount - 1))
                    .round();
          totals[pointIndex] += history.data[sourceIndex].close * quantity;
        }
      }
      if (!mounted || _portfolioPeriod != period) return;
      setState(() => _portfolioSeries = totals);
    } catch (_) {
      if (!mounted || _portfolioPeriod != period) return;
      setState(() => _portfolioSeries = const <double>[]);
    } finally {
      if (mounted) setState(() => _portfolioHistoryLoading = false);
    }
  }

  Widget _portfolioTopPerformers(List<PortfolioPosition> positions) {
    final ranked = positions.map((position) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      final price = stock?.price ?? position.averageCost;
      return (
        position: position,
        price: price,
        percent: position.returnPercent(price),
      );
    }).toList()..sort((a, b) => b.percent.compareTo(a.percent));
    if (ranked.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            'Performance will appear after positions are settled.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }
    return SizedBox(
      height: 116,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ranked.take(6).length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = ranked[index];
          final positive = item.percent >= 0;
          return Container(
            width: 154,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConfig.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.position.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  item.position.exchange,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                  ),
                ),
                const Spacer(),
                Text(
                  formatPrice(item.price),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${positive ? '+' : ''}${item.percent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: positive ? AppConfig.gainColor : AppConfig.lossColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isSpecialCategory(String value) {
    final normalized = value.toUpperCase();
    return normalized.contains('INST') ||
        normalized.contains('LIMIT_UP') ||
        normalized.contains('OTC') ||
        normalized.contains('BLOCK') ||
        normalized.contains('IPO');
  }

  Widget _portfolioAllocationCard(List<PortfolioPosition> positionList) {
    const colors = <String, Color>{
      'Inst.': Color(0xFF16B8C4),
      'OTC': Color(0xFFF59E0B),
      'IPO': Color(0xFF7C3AED),
    };
    final values = <String, double>{for (final key in colors.keys) key: 0};
    for (final position in positionList) {
      final stock = _stockForOrNull(
        position.symbol,
        exchange: position.exchange,
      );
      final value = position.marketValue(stock?.price ?? position.averageCost);
      final text = '${position.category} ${stock?.category ?? ''}'
          .toUpperCase();
      final String? key = text.contains('IPO')
          ? 'IPO'
          : text.contains('OTC') || text.contains('BLOCK')
          ? 'OTC'
          : text.contains('INST') || text.contains('LIMIT_UP')
          ? 'Inst.'
          : null;
      if (key == null) continue;
      values[key] = (values[key] ?? 0) + value;
    }
    final total = values.values.fold<double>(0, (sum, value) => sum + value);
    final segments = colors.entries
        .map(
          (entry) => _AllocationSegment(
            label: entry.key,
            value: values[entry.key] ?? 0,
            color: entry.value,
          ),
        )
        .toList();
    final legend = Column(
      children: segments.map((segment) {
        final percent = total <= 0 ? 0 : segment.value / total * 100;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: segment.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 38,
                child: Text(
                  segment.label,
                  maxLines: 1,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatPrice(segment.value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                child: Text(
                  '${percent.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portfolio Breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 430;
                final chart = SizedBox(
                  width: compact ? 132 : 142,
                  height: compact ? 132 : 142,
                  child: CustomPaint(
                    painter: _AllocationDonutPainter(segments),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: FittedBox(
                              child: Text(
                                formatPrice(total),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                if (compact) {
                  return Column(
                    children: [
                      Center(child: chart),
                      const SizedBox(height: 12),
                      legend,
                    ],
                  );
                }
                return Row(
                  children: [
                    chart,
                    const SizedBox(width: 22),
                    Expanded(child: legend),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _portfolioMetric(String label, double value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPrice(value),
              style: TextStyle(
                color: color ?? AppConfig.textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _accountFundValue(
    String label,
    double value, {
    String? displayValue,
    IconData? icon,
    Color color = AppConfig.primaryColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
            ],
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      displayValue ?? formatPrice(value),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 17,
                    color: Color(0xFF64748B),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profitLossCard(String label, double value, IconData icon) {
    final isPositive = value >= 0;

    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '${isPositive ? '+' : '-'}${formatPrice(value.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionCard(PortfolioPosition position) {
    final stock = _stockFor(position.symbol, exchange: position.exchange);

    final marketValue = position.marketValue(stock.price);

    final profitLoss = position.unrealizedProfitLoss(stock.price);

    final isPositive = profitLoss >= 0;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _openStock(stock);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  StockLogo(symbol: position.symbol, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position.symbol,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${position.quantity} shares',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatPrice(marketValue),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${isPositive ? '+' : '-'}${formatPrice(profitLoss.abs())}',
                        style: TextStyle(
                          color: isPositive
                              ? AppConfig.gainColor
                              : AppConfig.lossColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _orderValue(
                      'Current price',
                      formatPrice(stock.price),
                    ),
                  ),
                  Expanded(
                    child: _orderValue(
                      'Return',
                      '${isPositive ? '+' : ''}'
                          '${position.returnPercent(stock.price).toStringAsFixed(2)}%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _positionKey(String exchange, String symbol) =>
      '${exchange.trim().toUpperCase()}:${symbol.trim().toUpperCase()}';

  StockQuote _stockFor(String symbol, {String? exchange}) {
    return stocks.firstWhere(
      (stock) =>
          stock.symbol == symbol &&
          (exchange == null || stock.exchange == exchange),
    );
  }

  StockQuote? _stockForOrNull(String symbol, {String? exchange}) {
    for (final stock in stocks) {
      if (stock.symbol == symbol &&
          (exchange == null || stock.exchange == exchange)) {
        return stock;
      }
    }

    return null;
  }

  Widget _accountBody() {
    final holdingsValue = positions.values.fold<double>(0, (total, position) {
      final stock = _stockFor(position.symbol, exchange: position.exchange);

      return total + position.marketValue(stock.price);
    });

    final totalAssets = cashBalance + holdingsValue;

    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? 14.0
        : 22.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        18,
        horizontalPadding,
        28,
      ),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => _openAccountSettings('preferences'),
              icon: const Icon(Icons.settings_outlined, size: 27),
            ),
            _notificationButton(),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    InkWell(
                      onTap: _pickProfileAvatar,
                      borderRadius: BorderRadius.circular(40),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: const Color(0xFFE7F0FF),
                        backgroundImage: profileAvatarBytes == null
                            ? null
                            : MemoryImage(profileAvatarBytes!),
                        child: profileAvatarBytes == null
                            ? Text(
                                _accountInitials,
                                style: const TextStyle(
                                  color: AppConfig.primaryColor,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            accountName,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+91 $accountPhone',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                avatar: Icon(
                                  kycStatus == 'APPROVED'
                                      ? Icons.verified
                                      : kycStatus == 'PENDING'
                                      ? Icons.schedule_rounded
                                      : Icons.info_outline_rounded,
                                  color: kycStatus == 'APPROVED'
                                      ? Colors.green
                                      : kycStatus == 'PENDING'
                                      ? Colors.orange
                                      : Colors.blueGrey,
                                  size: 18,
                                ),
                                label: Text(
                                  kycStatus == 'APPROVED'
                                      ? 'Verified'
                                      : kycStatus == 'PENDING'
                                      ? 'KYC Pending'
                                      : 'KYC Required',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit profile',
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth < 420 ? 2 : 4;
                    final itemWidth = constraints.maxWidth / columns;
                    return Wrap(
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue(
                            'Balance',
                            availableBalance,
                            icon: Icons.account_balance_wallet_outlined,
                            onTap: () => setState(() => selectedIndex = 2),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue(
                            'Portfolio',
                            totalAssets,
                            icon: Icons.trending_up_rounded,
                            color: AppConfig.gainColor,
                            onTap: () {
                              setState(() => selectedIndex = 3);
                              unawaited(
                                _loadPortfolioHistory(_portfolioPeriod),
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue(
                            'Rewards',
                            0,
                            displayValue: 'Not active',
                            icon: Icons.star_border_rounded,
                            color: const Color(0xFFF59E0B),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ReferralPage(code: ''),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue(
                            'Coupons',
                            0,
                            displayValue: '0 Available',
                            icon: Icons.confirmation_number_outlined,
                            color: const Color(0xFF7C3AED),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const OffersPage(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE9F2FF), Color(0xFFF5F8FF)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 27,
                backgroundColor: Color(0xFFD9E9FF),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: AppConfig.primaryColor,
                  size: 30,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Exclusive research and priority support',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => _openCustomerService(
                  title: 'Premium account',
                  initialMessage:
                      'Hello, I would like information about Premium account eligibility.',
                  icon: Icons.workspace_premium_outlined,
                ),
                child: const Text('Upgrade'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Account & Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                subtitle: 'Update your profile, email, phone and address',
                onTap: _editProfile,
                color: const Color(0xFF2563EB),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.verified_user_outlined,
                title: 'Security',
                subtitle: 'Password, biometric and device access',
                onTap: () => _openAccountSettings('security'),
                color: const Color(0xFF10B981),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank Accounts',
                subtitle: 'Manage linked bank accounts and UPI',
                onTap: () => _openAccountSettings('banks'),
                color: const Color(0xFFF59E0B),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.description_outlined,
                title: 'KYC Details',
                subtitle: 'View and update your KYC information',
                onTap: () => _openAccountSettings('kyc'),
                color: const Color(0xFF8B5CF6),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.tune_rounded,
                title: 'Preferences',
                subtitle: 'App settings, notifications and theme',
                onTap: () => _openAccountSettings('preferences'),
                color: const Color(0xFF06B6D4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Support & More',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'FAQs, contact support and raise a ticket',
                onTap: () => _openCustomerService(
                  title: 'Help & support',
                  initialMessage: 'Hello, I need help with my account.',
                  icon: Icons.help_outline,
                ),
                color: const Color(0xFF2563EB),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.menu_book_outlined,
                title: 'Learning Center',
                subtitle: 'Tutorials and trading guides',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LearningCenterPage(),
                  ),
                ),
                color: const Color(0xFF10B981),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.campaign_outlined,
                title: 'Refer & Earn',
                subtitle: 'Invite friends and earn rewards',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ReferralPage(code: ''),
                  ),
                ),
                color: const Color(0xFFF59E0B),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.info_outline_rounded,
                title: 'About Us',
                subtitle: 'About our app, terms and policies',
                onTap: _openAbout,
                color: const Color(0xFF8B5CF6),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Securely logout from your account',
                onTap: _confirmSignOut,
                color: AppConfig.lossColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          AppConfig.appName,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black45, fontSize: 12),
        ),
      ],
    );
  }

  Widget _accountTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color color = const Color(0xFF143D8D),
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
      ),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConfig.appName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text('Version 1.0.0'),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: const Text('Terms of Service'),
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
                title: const Text('Privacy Policy'),
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
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'Your account data is saved on this '
          'device and will be restored after '
          'you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
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
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _confirmResetAccount() {
    _openCustomerService(
      title: 'Account support',
      initialMessage:
          'Hello, I need help checking or correcting my trading account records.',
      icon: Icons.support_agent_outlined,
    );
  }
}

class _HomeMoneyCard extends StatelessWidget {
  const _HomeMoneyCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  const _HomeActionButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8EDF5)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllocationSegment {
  const _AllocationSegment({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;
}

class _MiniLineChartPainter extends CustomPainter {
  const _MiniLineChartPainter({
    required this.color,
    this.values = const <double>[],
  });

  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final source = values;
    final minimum = source.reduce((left, right) => math.min(left, right));
    final maximum = source.reduce((left, right) => math.max(left, right));
    final spread = math.max(maximum - minimum, maximum.abs() * .01).toDouble();
    final normalized = source
        .map((value) => .88 - ((value - minimum) / spread) * .76)
        .toList(growable: false);
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    final path = Path();
    for (var index = 0; index < normalized.length; index++) {
      final point = Offset(
        size.width * index / (normalized.length - 1),
        size.height * normalized[index],
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, fill);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}

class _AllocationDonutPainter extends CustomPainter {
  const _AllocationDonutPainter(this.segments);
  final List<_AllocationSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.value,
    );
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * .18;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    if (total <= 0) {
      paint.color = const Color(0xFFE8EDF5);
      canvas.drawArc(rect.deflate(stroke / 2), 0, math.pi * 2, false, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweep = math.pi * 2 * segment.value / total;
      paint.color = segment.color;
      canvas.drawArc(rect.deflate(stroke / 2), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _AllocationDonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
