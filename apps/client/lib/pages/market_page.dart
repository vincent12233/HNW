import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/institutional_opportunity.dart';
import '../models/ipo.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../models/withdrawal_request.dart';
import '../services/auth_service.dart';
import '../services/ipo_service.dart';
import '../services/market_data_service.dart';
import '../services/market_socket_service.dart';
import '../services/trading_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/market_header.dart';
import '../widgets/market_news.dart';
import '../widgets/stock_logo.dart';
import 'login_page.dart';
import 'markets_page.dart';
import 'stock_detail_page.dart';
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

  double cashBalance = 0;
  double realizedProfitLoss = 0;

  double nifty50Price = 0;
  double nifty50Change = 0;

  double sensexPrice = 0;
  double sensexChange = 0;

  double bankNiftyPrice = 0;
  double bankNiftyChange = 0;

  String accountName = 'Client';
  String accountPhone = '';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
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

        final index = stocks.indexWhere((stock) => stock.symbol == symbol);

        if (index >= 0) {
          stocks[index] = StockQuote(
            stocks[index].symbol,
            stocks[index].name,
            price,
            change,
            int.tryParse(data['volume'].toString()) ?? stocks[index].volume,
            DateTime.tryParse(data['updatedAt'].toString()) ?? DateTime.now(),
          );
        }
      });
    };

    _loadAppData();
  }

  @override
  void dispose() {
    marketSocket.dispose();
    super.dispose();
  }

  Future<void> _loadAppData() async {
    final session = await AuthService().restoreSession();

    accountName = session?.fullName.isNotEmpty == true
        ? session!.fullName
        : 'Client';
    accountPhone = session?.phone ?? '';

    stocks
      ..clear()
      ..addAll(_fallbackStocks());
    ipos
      ..clear()
      ..addAll(_fallbackIpos());

    try {
      final remoteStocks = await marketDataService.fetchSnapshot();
      if (remoteStocks.isNotEmpty) {
        stocks
          ..clear()
          ..addAll(remoteStocks);
      }
    } catch (_) {
      // Read-only fallback market list stays visible if the API is unavailable.
    }

    try {
      final snapshot = await tradingService.fetchAccountSnapshot();
      if (snapshot != null) {
        cashBalance = snapshot.cashBalance;
        realizedProfitLoss = snapshot.realizedProfitLoss;
        positions
          ..clear()
          ..addEntries(
            snapshot.positions.map(
              (position) => MapEntry(position.symbol, position),
            ),
          );
      }
    } catch (_) {
      cashBalance = 0;
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

  List<StockQuote> _fallbackStocks() {
    final now = DateTime.now();
    return <StockQuote>[
      StockQuote('RELIANCE', 'Reliance Industries', 1334.8, 1.82, 9880895, now),
      StockQuote('TCS', 'Tata Consultancy Services', 2452.7, 1.65, 4547325, now),
      StockQuote('HDFCBANK', 'HDFC Bank', 731, 2.45, 19372672, now),
      StockQuote('INFY', 'Infosys', 1928.60, -0.85, 0, now),
      StockQuote('ICICIBANK', 'ICICI Bank', 1284.30, 1.18, 0, now),
    ];
  }

  List<Ipo> _fallbackIpos() {
    return <Ipo>[
      Ipo(
        id: 'FALLBACK_TATACAP',
        symbol: 'TATACAP',
        companyName: 'Tata Capital Limited',
        marketPrice: 1185.60,
        subscriptionPrice: 1020.00,
        lotSize: 100,
        status: IpoStatus.upcoming,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              bottom: false,
              child: _selectedBody(),
            ),
      bottomNavigationBar: NavigationBar(
        height: 78,
        elevation: 0,
        backgroundColor: const Color(0xFFF3F5FA),
        indicatorColor: const Color(0xFFDDE8FF),
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
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart, color: AppConfig.primaryColor),
            label: 'Markets',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz, color: AppConfig.primaryColor),
            label: 'Trading',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(
              Icons.account_balance_wallet,
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
          onStockTap: _openStock,
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
      final stock = _stockForOrNull(position.symbol);
      holdingsValue += position.marketValue(stock?.price ?? position.averageCost);
    }

    final totalPortfolioValue = cashBalance + holdingsValue;
    final todayPnl = positions.values.fold<double>(0, (total, position) {
      final stock = _stockForOrNull(position.symbol);
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
                    width: 92,
                    height: 46,
                    child: CustomPaint(
                      painter: _MiniLinePainter(
                        color: const Color(0xFF22C55E),
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
        Row(
          children: [
            Expanded(
              child: _HomeMoneyCard(
                title: 'Available Cash',
                value: formatPrice(cashBalance),
                icon: Icons.account_balance_wallet_outlined,
                color: AppConfig.primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HomeMoneyCard(
                title: "Today's P&L",
                value:
                    '${pnlPositive ? '+' : '-'}${formatPrice(todayPnl.abs())}',
                subtitle: positions.isEmpty ? '+0.00%' : 'Live holdings',
                icon: pnlPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: pnlPositive ? AppConfig.gainColor : AppConfig.lossColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _homeQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _HomeActionButton(
            label: 'Deposit',
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
    ];

    return Row(
      children: indices.map((item) {
        final positive = item.$3 >= 0;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: item.$1 == 'BANK NIFTY' ? 0 : 8,
            ),
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
                  Text(
                    item.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
                      color:
                          positive ? AppConfig.gainColor : AppConfig.lossColor,
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
    final gainers = [...stocks]
      ..sort((a, b) => b.change.compareTo(a.change));
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
    _openCustomerService(
      title: 'Deposit Support',
      initialMessage: 'Hello, I would like to make a deposit.',
      icon: Icons.add_circle_outline,
    );
  }

  Future<void> _openWithdrawalRequest() async {
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
                          _withdrawBankRow('Account Holder', accountName),
                          const SizedBox(height: 10),
                          _withdrawBankRow('Bank Account', '****4582'),
                          const SizedBox(height: 10),
                          _withdrawBankRow('Bank Status', 'Verified'),
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
        bankName: 'Linked Bank Account',
        accountNumber: '00004582',
        ifscCode: 'HDFC0000001',
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
                  'No balance changes are made from this page. '
                  'Deposits are handled by customer service. Withdrawals can be submitted in the app.',
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
                      content: Text('Customer service request submitted'),
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
              label: const Text('Contact Support'),
            ),
          ],
        );
      },
    ).whenComplete(() {
      messageController.dispose();
    });
  }

  Widget _marketBody() {
    return Container(
      color: AppConfig.backgroundColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MarketHeader(
            accountName: accountName,
            onNotificationTap: _openNotifications,
            notificationCount: pendingOrders.length +
                ipoApplications
                    .where(
                      (application) =>
                          application.status ==
                              IpoApplicationStatus.allocated &&
                          application.remainingAmount > 0,
                    )
                    .length,
          ),
          const SizedBox(height: 14),
          _homeFundsCard(),
          const SizedBox(height: 10),
          _homeQuickActions(),
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
          const MarketNews(),
        ],
      ),
    );
  }

  void _openNotifications() {
    final outstandingIpos = ipoApplications
        .where(
          (application) =>
              application.status == IpoApplicationStatus.allocated &&
              application.remainingAmount > 0,
        )
        .toList();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                if (pendingOrders.isEmpty && outstandingIpos.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No pending updates',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ),
                ...pendingOrders.take(3).map(
                  (order) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text('${order.symbol} order pending'),
                    subtitle: Text('${order.side.name} ${order.quantity} shares'),
                  ),
                ),
                ...outstandingIpos.take(3).map(
                  (application) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.campaign_outlined),
                    title: Text('${application.symbol} IPO outstanding'),
                    subtitle: Text(
                      'Remaining ${formatPrice(application.remainingAmount)}',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openStock(StockQuote stock) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StockDetailPage(
          stock: stock,
          onOrderPlaced: _placeOrder,
        ),
      ),
    );
  }

  Future<String?> _placeOrder(TradingOrder order) async {
    final existing = positions[order.symbol];

    if (order.isBuy && order.amount > cashBalance) {
      return 'Insufficient Available Balance. Available: '
          '${formatPrice(cashBalance)}';
    }

    if (!order.isBuy &&
        (existing == null || existing.quantity < order.quantity)) {
      return 'Insufficient holdings. Available: '
          '${existing?.quantity ?? 0}';
    }

    try {
      final confirmedOrder = await tradingService.placeMarketOrder(order);
      final snapshot = await tradingService.fetchAccountSnapshot();
      final remoteOrders = await tradingService.fetchOrders();

      if (snapshot != null) {
        setState(() {
          cashBalance = snapshot.cashBalance;
          realizedProfitLoss = snapshot.realizedProfitLoss;
          positions
            ..clear()
            ..addEntries(
              snapshot.positions.map(
                (position) => MapEntry(position.symbol, position),
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
          realizedProfitLoss = snapshot.realizedProfitLoss;
          positions
            ..clear()
            ..addEntries(
              snapshot.positions.map(
                (position) => MapEntry(position.symbol, position),
              ),
            );
        }
        orders
          ..clear()
          ..addAll(remoteOrders);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trading data refreshed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  // ignore: unused_element
  Widget _portfolioBody() {
    final positionList = positions.values.toList()
      ..sort((a, b) => a.symbol.compareTo(b.symbol));

    final holdingsValue = positionList.fold<double>(
      0,
      (total, position) =>
          total + position.marketValue(_stockFor(position.symbol).price),
    );

    final unrealizedProfitLoss = positionList.fold<double>(
      0,
      (total, position) =>
          total +
          position.unrealizedProfitLoss(_stockFor(position.symbol).price),
    );

    final totalAssets = cashBalance + holdingsValue;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Portfolio',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Trading Account overview',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF143D8D), Color(0xFF2563C7)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total assets',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                formatPrice(totalAssets),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _summaryValue(
                      'Available funds',
                      formatPrice(cashBalance),
                    ),
                  ),
                  Expanded(
                    child: _summaryValue(
                      'Holdings value',
                      formatPrice(holdingsValue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'My Holdings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${positionList.length} stock'
              '${positionList.length == 1 ? '' : 's'}',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (positionList.isEmpty)
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 58,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No holdings yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Place a Buy order to build your portfolio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
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
          )
        else
          ...positionList.map(_positionCard),
      ],
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
    final stock = _stockFor(position.symbol);

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

  StockQuote _stockFor(String symbol) {
    return stocks.firstWhere((stock) => stock.symbol == symbol);
  }

  StockQuote? _stockForOrNull(String symbol) {
    for (final stock in stocks) {
      if (stock.symbol == symbol) {
        return stock;
      }
    }

    return null;
  }

  Widget _accountBody() {
    final holdingsValue = positions.values.fold<double>(0, (total, position) {
      final stock = _stockFor(position.symbol);

      return total + position.marketValue(stock.price);
    });

    final totalAssets = cashBalance + holdingsValue;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: AppConfig.primaryColor,
                  child: Icon(
                    Icons.candlestick_chart,
                    size: 36,
                    color: Colors.white,
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
                            label: Text('KYC Verified'),
                          ),
                          Chip(label: Text('Order')),
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
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF143D8D), Color(0xFF2563C7)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trading Account value',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Text(
                formatPrice(totalAssets),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Available ${formatPrice(cashBalance)} • '
                '${positions.length} holding'
                '${positions.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Account details',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _accountTile(
                icon: Icons.badge_outlined,
                title: 'Client ID',
                subtitle: 'IT-SBX-100001',
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.verified_user_outlined,
                title: 'KYC & Verification',
                subtitle: 'Identity Verified',
                onTap: () => _showInformation(
                  'KYC & verification',
                  'Your identity verification status is complete. '
                      'You can manage your KYC information and account verification here.',
                ),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.account_balance_outlined,
                title: 'Linked bank account',
                subtitle: 'Bank Account ****4582',
                onTap: () => _showInformation(
                  'Linked bank account',
                  'This is your linked bank account.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Settings',
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
                subtitle: 'Ask support to update notification preferences',
                onTap: () => _openCustomerService(
                  title: 'Notification support',
                  initialMessage:
                      'Hello, I need help with order notification preferences.',
                  icon: Icons.notifications_outlined,
                ),
              ),
              const Divider(height: 1, indent: 56),
              _accountTile(
                icon: Icons.lock_outline,
                title: 'Security',
                subtitle: 'Password and device access',
                onTap: () => _openCustomerService(
                  title: 'Security support',
                  initialMessage:
                      'Hello, I need help with password or device access for my account.',
                  icon: Icons.lock_outline,
                ),
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
    _openCustomerService(
      title: 'Profile support',
      initialMessage:
          'Hello, I need to update my profile information for +91 $accountPhone.',
      icon: Icons.manage_accounts_outlined,
    );
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

class _MiniLinePainter extends CustomPainter {
  const _MiniLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(0, size.height * 0.68),
      Offset(size.width * 0.16, size.height * 0.52),
      Offset(size.width * 0.31, size.height * 0.62),
      Offset(size.width * 0.48, size.height * 0.30),
      Offset(size.width * 0.64, size.height * 0.42),
      Offset(size.width * 0.82, size.height * 0.22),
      Offset(size.width, size.height * 0.10),
    ];

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
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
