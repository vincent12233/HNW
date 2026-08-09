import 'package:flutter/material.dart';

import '../models/institutional_opportunity.dart';
import '../models/ipo.dart';
import '../models/pending_order.dart';
import '../models/portfolio_position.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../widgets/trading/history_tab.dart';
import '../widgets/trading/holdings_tab.dart';
import '../widgets/trading/institutional_tab.dart';
import '../widgets/trading/ipo_tab.dart';
import '../widgets/trading/orders_tab.dart';
import '../widgets/trading/otc_tab.dart';
import '../widgets/trading/pending_center_tab.dart';
import '../widgets/trading/trade_list.dart';
import '../widgets/stock_logo.dart';

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
    required this.onAllocateIpo,
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

  final void Function(String applicationId, int allocatedQuantity)
  onAllocateIpo;

  @override
  State<TradingCenterPage> createState() => _TradingCenterPageState();
}

class _TradingCenterPageState extends State<TradingCenterPage> {
  int selectedTab = 0;

  final List<_TradingModule> tabs = const [
    _TradingModule('Trades', Icons.swap_horiz_rounded, Color(0xFF2563EB)),
    _TradingModule(
      'Holdings',
      Icons.account_balance_wallet_outlined,
      Color(0xFF059669),
    ),
    _TradingModule('Pending', Icons.schedule_rounded, Color(0xFFF97316)),
    _TradingModule(
      'Orders',
      Icons.receipt_long_outlined,
      Color(0xFF7C3AED),
    ),
    _TradingModule('IPO', Icons.campaign_outlined, Color(0xFFEF4444)),
    _TradingModule('OTC', Icons.handshake_outlined, Color(0xFF0D9488)),
    _TradingModule(
      'Inst.',
      Icons.account_balance_outlined,
      Color(0xFF1D4ED8),
    ),
    _TradingModule('History', Icons.history_rounded, Color(0xFFF59E0B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Trading Center',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Search',
                    onPressed: _openTradingSearch,
                    icon: const Icon(Icons.search_rounded),
                  ),
                  IconButton(
                    tooltip: 'Alerts',
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 86,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      setState(() {
                        selectedTab = index;
                      });
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
        return TradeList(stocks: widget.stocks, onTrade: widget.onTrade);

      case 1:
        return HoldingsTab(
          positions: widget.positions,
          stocks: widget.stocks,
          onStockTap: widget.onTrade,
        );

      case 2:
        return PendingCenterTab(
          pendingOrders: widget.pendingOrders,
          ipoApplications: widget.ipoApplications,
          onAllocateIpo: widget.onAllocateIpo,
        );

      case 3:
        return OrdersTab(orders: widget.orders);

      case 4:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
        );

      case 5:
        return OtcTab(opportunities: widget.institutionalStocks);

      case 6:
        return InstitutionalTab(stocks: widget.institutionalStocks);

      case 7:
        return HistoryTab(orders: widget.orders);

      default:
        return const SizedBox.shrink();
    }
  }

  void _openTradingSearch() {
    showSearch<StockQuote?>(
      context: context,
      delegate: _TradingStockSearchDelegate(
        stocks: widget.stocks,
        onSelected: widget.onTrade,
      ),
    );
  }
}

class _TradingModule {
  const _TradingModule(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

class _TradingStockSearchDelegate extends SearchDelegate<StockQuote?> {
  _TradingStockSearchDelegate({
    required this.stocks,
    required this.onSelected,
  });

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
          icon: const Icon(Icons.close_rounded),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back_rounded),
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

        return ListTile(
          leading: StockLogo(symbol: stock.symbol, size: 40),
          title: Text(
            stock.symbol,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(stock.name),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            close(context, stock);
            onSelected(stock);
          },
        );
      },
    );
  }
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
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? module.color : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: module.color.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
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
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
