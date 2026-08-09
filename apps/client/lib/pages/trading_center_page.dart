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

  final List<String> tabs = const [
    'Trades',
    'Holdings',
    'Pending',
    'Orders',
    'Inst.',
    'IPO',
    'OTC',
    'History',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Trading Center',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = selectedTab == index;

                  return ChoiceChip(
                    label: Text(tabs[index]),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

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
        return InstitutionalTab(stocks: widget.institutionalStocks);

      case 5:
        return IpoTab(
          ipos: widget.ipos,
          applications: widget.ipoApplications,
          onApply: widget.onApplyIpo,
        );

      case 6:
        return OtcTab(opportunities: widget.institutionalStocks);

      case 7:
        return HistoryTab(orders: widget.orders);

      default:
        return const SizedBox.shrink();
    }
  }
}
