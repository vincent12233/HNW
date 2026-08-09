import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../utils/number_formatters.dart';
import '../widgets/sector_performance.dart';
import '../widgets/stock_list_tile.dart';

class MarketsPage extends StatefulWidget {
  const MarketsPage({
    super.key,
    required this.stocks,
    required this.favoriteSymbols,
    required this.onStockTap,
    required this.onFavoriteToggle,
  });

  final List<StockQuote> stocks;
  final Set<String> favoriteSymbols;
  final ValueChanged<StockQuote> onStockTap;
  final ValueChanged<StockQuote> onFavoriteToggle;

  @override
  State<MarketsPage> createState() => _MarketsPageState();
}

class _MarketsPageState extends State<MarketsPage> {
  int selectedTab = 0;
  String query = '';

  final tabs = const [
    'Stocks',
    'Watchlist',
    'Gainers',
    'Losers',
    'Sectors',
    'ETF',
  ];

  List<StockQuote> get _filteredStocks {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return widget.stocks;
    }

    return widget.stocks.where((stock) {
      return stock.symbol.toLowerCase().contains(normalizedQuery) ||
          stock.name.toLowerCase().contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Markets',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 210,
                    child: SearchBar(
                      hintText: 'Search',
                      leading: const Icon(Icons.search, size: 20),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          query = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 46,
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
            const SizedBox(height: 12),
            Expanded(child: _selectedContent()),
          ],
        ),
      ),
    );
  }

  Widget _selectedContent() {
    switch (selectedTab) {
      case 0:
        return _stockList(_filteredStocks, emptyTitle: 'No stocks found');

      case 1:
        final watchlist = _filteredStocks
            .where((stock) => widget.favoriteSymbols.contains(stock.symbol))
            .toList();

        return _stockList(
          watchlist,
          emptyTitle: 'Your watchlist is empty',
          emptySubtitle: 'Tap the star beside a stock to save it here.',
        );

      case 2:
        final gainers =
            _filteredStocks.where((stock) => stock.change > 0).toList()
              ..sort((a, b) => b.change.compareTo(a.change));

        return _stockList(gainers, emptyTitle: 'No gainers right now');

      case 3:
        final losers =
            _filteredStocks.where((stock) => stock.change < 0).toList()
              ..sort((a, b) => a.change.compareTo(b.change));

        return _stockList(losers, emptyTitle: 'No losers right now');

      case 4:
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectorPerformance(stocks: widget.stocks),
            const SizedBox(height: 18),
            _sectorBreakdown(),
          ],
        );

      case 5:
        return _etfList();

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _stockList(
    List<StockQuote> stocks, {
    required String emptyTitle,
    String emptySubtitle = 'Try a different search or market filter.',
  }) {
    if (stocks.isEmpty) {
      return _emptyState(Icons.search_off, emptyTitle, emptySubtitle);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stocks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final stock = stocks[index];

        return StockListTile(
          stock: stock,
          isFavorite: widget.favoriteSymbols.contains(stock.symbol),
          onTap: () {
            widget.onStockTap(stock);
          },
          onFavorite: () {
            widget.onFavoriteToggle(stock);
          },
        );
      },
    );
  }

  Widget _sectorBreakdown() {
    final rows = [
      ('Banking', 'HDFCBANK, ICICIBANK', Icons.account_balance_outlined),
      ('Information Technology', 'TCS, INFY', Icons.memory_outlined),
      ('Energy', 'RELIANCE', Icons.bolt_outlined),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sector Constituents',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        ...rows.map((row) {
          return Card(
            child: ListTile(
              leading: Icon(row.$3, color: AppConfig.primaryColor),
              title: Text(row.$1),
              subtitle: Text(row.$2),
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        }),
      ],
    );
  }

  Widget _etfList() {
    final etfs = [
      ('NIFTYBEES', 'Nippon India ETF Nifty 50', 282.45, 0.42),
      ('BANKBEES', 'Nippon India ETF Bank BeES', 532.10, -0.18),
      ('JUNIORBEES', 'Nippon India ETF Junior BeES', 745.35, 0.27),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: etfs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final etf = etfs[index];
        final positive = etf.$4 >= 0;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.pie_chart_outline)),
            title: Text(etf.$1),
            subtitle: Text(etf.$2),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPrice(etf.$3),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${positive ? '+' : ''}${etf.$4.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: positive ? AppConfig.gainColor : AppConfig.lossColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
