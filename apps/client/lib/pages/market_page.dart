import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/institutional_opportunity.dart';
import '../models/ipo.dart';
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
import '../services/otc_service.dart';
import '../services/trading_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/market_header.dart';
import '../widgets/stock_logo.dart';
import 'login_page.dart';
import 'markets_page.dart';
import 'notifications_page.dart';
import 'account_settings_page.dart';
import 'stock_detail_page.dart';
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
  int selectedIndex = 0;
  bool isLoading = true;
  bool _ipoAllocationDialogOpen = false;
  bool marketConnected = false;
  bool? marketOpen;
  int unreadNotificationCount = 0;
  String marketHours = '09:15 - 15:30 IST';
  Timer? _marketSessionTimer;

  double cashBalance = 0;
  double buyingPower = 0;
  double frozenBalance = 0;
  double realizedProfitLoss = 0;

  double nifty50Price = 0;
  double nifty50Change = 0;

  double sensexPrice = 0;
  double sensexChange = 0;

  double bankNiftyPrice = 0;
  double bankNiftyChange = 0;

  String accountName = 'Client';
  String accountPhone = '';
  String accountNumber = '';
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

    marketSocket.onQuoteUpdate = (data) {
      final symbol = data['symbol']?.toString();

      final price = double.tryParse(data['price'].toString());

      final change = double.tryParse(data['change'].toString()) ?? 0;

      if (symbol == null || price == null) {
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
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
    ]);
    if (!mounted) return;
    final refreshedStocks = results[0] as List<StockQuote>;
    final indices = results[1] as List<Map<String, dynamic>>;
    final session = results[2] as Map<String, dynamic>?;
    final refreshedInstitutional = results[3] as List<InstitutionalStock>;
    setState(() {
      if (refreshedStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(refreshedStocks);
      }
      for (final item in indices) {
        final symbol = item['symbol']?.toString();
        final price = double.tryParse(item['price']?.toString() ?? '');
        final change = double.tryParse(item['change']?.toString() ?? '') ?? 0;
        if (price == null) continue;
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
    });
  }

  @override
  void dispose() {
    _marketSessionTimer?.cancel();
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

    if (mounted) {
      setState(() {
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || selectedIndex != 0) {
          return;
        }

        _showPendingIpoAllocationIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(bottom: false, child: _selectedBody()),
                Positioned(
                  right: 0,
                  bottom: 96,
                  child: SafeArea(child: _sideCustomerServiceButton()),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        height: 72,
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
            selectedIcon: Icon(Icons.bar_chart, color: AppConfig.primaryColor),
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
            selectedIcon: Icon(Icons.person, color: AppConfig.primaryColor),
            label: 'Account',
          ),
        ],
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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0B5CFF), Color(0xFF0648D8)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220B5CFF),
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
                  const Text(
                    'Total Portfolio Value',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.visibility_outlined,
                    color: Colors.white.withValues(alpha: 0.72),
                    size: 16,
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
                    child: CustomPaint(
                      painter: _MiniLineChartPainter(
                        color: const Color(0xFF4ADE80),
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
                  cashBalance,
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
            icon: Icons.support_agent_outlined,
            color: AppConfig.primaryColor,
            onTap: _openDepositSupport,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _HomeActionButton(
            label: 'Withdraw',
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
    ];

    return Row(
      children: indices.map((item) {
        final positive = item.$3 >= 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: item.$1 == 'BANK NIFTY' ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.all(12),
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
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        item.$4,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${positive ? '+' : ''}${item.$3.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: positive
                          ? AppConfig.gainColor
                          : AppConfig.lossColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _compactMovers() {
    final gainers = [...stocks]..sort((a, b) => b.change.compareTo(a.change));
    final losers = [...stocks]..sort((a, b) => a.change.compareTo(b.change));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _compactMoverList('Top Gainers', gainers, true)),
        const SizedBox(width: 10),
        Expanded(child: _compactMoverList('Top Losers', losers, false)),
      ],
    );
  }

  Widget _compactMoverList(String title, List<StockQuote> list, bool positive) {
    final color = positive ? AppConfig.gainColor : AppConfig.lossColor;
    final items = list
        .where((stock) => positive ? stock.change >= 0 : stock.change < 0)
        .take(3)
        .toList();

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
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...items.map(
            (stock) => InkWell(
              onTap: () => _openStock(stock),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        stock.symbol,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatPrice(stock.price),
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${stock.change > 0 ? '+' : ''}${stock.change.toStringAsFixed(2)}%',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
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
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              Icon(Icons.support_agent_rounded, color: Colors.white, size: 18),
              SizedBox(height: 6),
              RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'Support',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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
                      formatPrice(cashBalance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppConfig.primaryColor,
                      ),
                    ),

                    const SizedBox(height: 20),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Withdrawal Amount',
                        prefixText: '₹ ',
                        border: const OutlineInputBorder(),
                        errorText: errorText,
                      ),
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
                          _withdrawBankRow('Account Holder', accountName),
                          const SizedBox(height: 10),
                          _withdrawBankRow(
                            'Bank Account',
                            selectedBank['accountNumber']?.toString() ?? '',
                          ),
                          const SizedBox(height: 10),
                          _withdrawBankRow('Bank Status', 'Added'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'Your withdrawal request will be submitted for review. '
                      'Funds will not be deducted until the request is processed.',
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
                              if (!mounted) return;
                              setState(() {
                                withdrawalRequests
                                  ..clear()
                                  ..addAll(latest);
                              });
                              setDialogState(() {});
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

                    if (amount == null || amount <= 0) {
                      setDialogState(() {
                        errorText = 'Enter a valid withdrawal amount';
                      });
                      return;
                    }

                    if (amount > cashBalance) {
                      setDialogState(() {
                        errorText =
                            'Maximum available: ${formatPrice(cashBalance)}';
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

    if (amount <= 0 || amount > cashBalance) {
      return;
    }

    late final WithdrawalRequest request;

    try {
      request = await AuthService().submitWithdrawal(
        amount: amount,
        bankName: selectedBank['bankName']?.toString() ?? '',
        accountNumber: selectedBank['accountNumber']?.toString() ?? '',
        ifscCode: selectedBank['ifscCode']?.toString() ?? '',
        note: 'App withdrawal request',
      );
    } on AuthException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    setState(() {
      withdrawalRequests.insert(0, request);
    });

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Withdrawal request ${request.orderNo ?? request.id} submitted',
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
    return Container(
      color: AppConfig.backgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MarketHeader(
            accountName: accountName,
            avatarBytes: profileAvatarBytes,
            onAvatarTap: _pickProfileAvatar,
            onSearchTap: () => showSearch<StockQuote?>(
              context: context,
              delegate: StockSearchDelegate(
                stocks: stocks,
                onSelected: _openStock,
              ),
            ),
            onNotificationTap: _openNotifications,
            notificationCount: unreadNotificationCount,
          ),
          const SizedBox(height: 14),
          _homeMarketStatus(),
          const SizedBox(height: 10),
          _homeFundsCard(),
          const SizedBox(height: 18),
          _sectionTitle(
            'Market Overview',
            onViewAll: () => setState(() => selectedIndex = 1),
          ),
          const SizedBox(height: 10),
          _marketOverviewGrid(),
          const SizedBox(height: 18),
          _compactMovers(),
          const SizedBox(height: 18),
          _sectionTitle('Market News'),
          const SizedBox(height: 10),
          _marketNewsSection(),
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
    const news = [
      (
        'Markets',
        'Indian equities track banking and technology momentum',
        Icons.show_chart_rounded,
        Color(0xFF1769FF),
      ),
      (
        'Economy',
        'RBI policy and liquidity remain in investor focus',
        Icons.account_balance_rounded,
        Color(0xFF7C3AED),
      ),
      (
        'Companies',
        'Earnings updates shape today’s active counters',
        Icons.apartment_rounded,
        Color(0xFF0891B2),
      ),
      (
        'Global',
        'Asian markets react to currency and commodity moves',
        Icons.public_rounded,
        Color(0xFFF59E0B),
      ),
    ];
    return Column(
      children: news
          .map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EDF5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: item.$4.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.$3, color: item.$4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1.toUpperCase(),
                          style: TextStyle(
                            color: item.$4,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage()));
    if (mounted) setState(() => unreadNotificationCount = 0);
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
      padding: const EdgeInsets.all(16),
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

  // ignore: unused_element
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

    final totalAssets = cashBalance + holdingsValue;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Portfolio',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: () => showSearch<StockQuote?>(
                context: context,
                delegate: StockSearchDelegate(
                  stocks: stocks,
                  onSelected: _openStock,
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 28),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF143D8D), Color(0xFF2563C7)],
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
                    child: const Text(
                      '1D⌄',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
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
                    child: CustomPaint(
                      painter: const _MiniLineChartPainter(
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${unrealizedProfitLoss >= 0 ? '+' : '-'}${formatPrice(unrealizedProfitLoss.abs())} Overall Returns',
                style: TextStyle(
                  color: unrealizedProfitLoss >= 0
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
                        child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: entry.key == 0
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: entry.key == 0
                                  ? AppConfig.primaryColor
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
                    final itemWidth = constraints.maxWidth < 390
                        ? constraints.maxWidth / 2
                        : constraints.maxWidth / 4;
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
                            unrealizedProfitLoss,
                            color: unrealizedProfitLoss >= 0
                                ? AppConfig.gainColor
                                : AppConfig.lossColor,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _portfolioMetric(
                            'Available Balance',
                            cashBalance,
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
                realizedProfitLoss,
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

  Widget _portfolioTopPerformers(List<PortfolioPosition> positions) {
    final ranked =
        positions
            .where((position) => _isSpecialCategory(position.category))
            .map((position) {
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
            })
            .toList()
          ..sort((a, b) => b.percent.compareTo(a.percent));
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
            Row(
              children: [
                SizedBox(
                  width: 142,
                  height: 142,
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
                          FittedBox(
                            child: Text(
                              formatPrice(total),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    children: segments.map((segment) {
                      final percent = total <= 0
                          ? 0
                          : segment.value / total * 100;
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
                            Expanded(
                              child: Text(
                                segment.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '${percent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 86,
                              child: Text(
                                formatPrice(segment.value),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
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

  Widget _accountFundValue(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 11),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatPrice(value),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Profile',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => _openAccountSettings('preferences'),
              icon: const Icon(Icons.settings_outlined, size: 27),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: const Icon(Icons.notifications_none_rounded, size: 28),
            ),
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
                            ? const Icon(
                                Icons.add_a_photo_outlined,
                                size: 32,
                                color: AppConfig.primaryColor,
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
                          const Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              Chip(
                                avatar: Icon(
                                  Icons.verified,
                                  color: Colors.green,
                                  size: 18,
                                ),
                                label: Text('Verified'),
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
                    final itemWidth = constraints.maxWidth < 390
                        ? constraints.maxWidth / 2
                        : constraints.maxWidth / 4;
                    return Wrap(
                      runSpacing: 14,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue('Balance', cashBalance),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue('Portfolio', totalAssets),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue('Rewards', 1250),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _accountFundValue('Coupons', 3),
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
                onPressed: () => _showInformation(
                  'Premium',
                  'Premium account options will be announced here.',
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
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.verified_user_outlined,
                title: 'KYC Details',
                subtitle: 'View and update your KYC information',
                onTap: () => _openAccountSettings('kyc'),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.account_balance_outlined,
                title: 'Bank Accounts',
                subtitle: 'Manage linked bank accounts and UPI',
                onTap: () => _openAccountSettings('banks'),
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
                icon: Icons.notifications_outlined,
                title: 'Order notifications',
                subtitle: 'Manage transaction and account alerts',
                onTap: () => _openAccountSettings('preferences'),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'Password and device access',
                onTap: () => _openAccountSettings('security'),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.fact_check_outlined,
                title: 'Portfolio reconciliation',
                subtitle: 'Inst., OTC and IPO settlement totals',
                onTap: () => _openAccountSettings('reconciliation'),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.pin_outlined,
                title: 'Transaction key',
                subtitle: 'Set or change the 6-digit OTC purchase key',
                onTap: _setTransactionKey,
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.help_outline,
                title: 'Help & support',
                subtitle: 'Get help with your account',
                onTap: () => _openCustomerService(
                  title: 'Help & support',
                  initialMessage: 'Hello, I need help with my account.',
                  icon: Icons.help_outline,
                ),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.restart_alt,
                title: 'Account support',
                subtitle: 'Request account data assistance',
                onTap: _confirmResetAccount,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            minimumSize: const Size.fromHeight(50),
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
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF143D8D)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _editProfile() {
    _openAccountSettings('profile');
  }

  Future<void> _openAccountSettings(String section) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AccountSettingsPage(section: section),
      ),
    );
  }

  Future<void> _setTransactionKey() async {
    final first = TextEditingController();
    final second = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transaction key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'New 6-digit key'),
            ),
            TextField(
              controller: second,
              obscureText: true,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Confirm key'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (submit != true || !mounted) return;
    if (first.text != second.text || !RegExp(r'^\d{6}$').hasMatch(first.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the same 6-digit key twice')),
      );
      return;
    }
    try {
      await OtcService().setTransactionKey(first.text);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction key updated')),
        );
    } on OtcException catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _showInformation(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('OK'),
          ),
        ],
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
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        height: 48,
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
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
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
  const _MiniLineChartPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const values = <double>[
      .72,
      .61,
      .66,
      .47,
      .55,
      .36,
      .42,
      .22,
      .31,
      .16,
      .08,
    ];
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
    for (var index = 0; index < values.length; index++) {
      final point = Offset(
        size.width * index / (values.length - 1),
        size.height * values[index],
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
      oldDelegate.color != color;
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

class StockSearchDelegate extends SearchDelegate<StockQuote?> {
  StockSearchDelegate({required this.stocks, required this.onSelected});

  final List<StockQuote> stocks;
  final ValueChanged<StockQuote> onSelected;

  List<StockQuote> get filteredStocks {
    final text = query.trim().toLowerCase();

    if (text.isEmpty) {
      return stocks;
    }

    return stocks.where((stock) {
      return stock.symbol.toLowerCase().contains(text) ||
          stock.name.toLowerCase().contains(text);
    }).toList();
  }

  @override
  String get searchFieldLabel => 'Search stocks';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () {
            query = '';
          },
          icon: const Icon(Icons.close),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final results = filteredStocks;

    if (results.isEmpty) {
      return const Center(child: Text('No stocks found'));
    }

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final stock = results[index];

        final color = stock.change > 0
            ? AppConfig.gainColor
            : stock.change < 0
            ? AppConfig.lossColor
            : AppConfig.neutralColor;

        return ListTile(
          leading: StockLogo(
            symbol: stock.symbol,
            size: 40,
            logoUrl: stock.logoUrl,
          ),
          title: Text(
            stock.symbol,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(stock.name),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPrice(stock.price),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${stock.change > 0 ? '+' : ''}'
                '${stock.change.toStringAsFixed(2)}%',
                style: TextStyle(color: color),
              ),
            ],
          ),
          onTap: () {
            close(context, stock);
            onSelected(stock);
          },
        );
      },
    );
  }
}
