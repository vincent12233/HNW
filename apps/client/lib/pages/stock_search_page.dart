import 'dart:async';

import 'package:flutter/material.dart';

import '../models/stock_quote.dart';
import '../services/market_data_service.dart';
import '../services/watchlist_service.dart';
import '../widgets/stock_list_tile.dart';

class StockSearchPage extends StatefulWidget {
  const StockSearchPage({
    super.key,
    required this.initialStocks,
    required this.onSelected,
    this.onWatchlistChanged,
  });

  final List<StockQuote> initialStocks;
  final ValueChanged<StockQuote> onSelected;
  final VoidCallback? onWatchlistChanged;

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends State<StockSearchPage> {
  final _controller = TextEditingController();
  final _marketData = MarketDataService();
  final _watchlistService = WatchlistService();
  Timer? _debounce;
  List<StockQuote> _results = const [];
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;
  Set<String> _watchlist = <String>{};
  final Set<String> _watchlistSaving = <String>{};
  bool _watchlistLoading = true;

  @override
  void initState() {
    super.initState();
    _results = widget.initialStocks;
    _loadWatchlist();
  }

  Future<void> _loadWatchlist() async {
    try {
      final values = await _watchlistService.fetchSymbols();
      if (!mounted) return;
      setState(() {
        _watchlist = values;
        _watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _watchlistLoading = false);
    }
  }

  Future<void> _toggleWatchlist(StockQuote stock) async {
    final key = WatchlistService.key(stock.exchange, stock.symbol);
    if (_watchlistSaving.contains(key)) return;
    final removing = _watchlist.contains(key);
    setState(() => _watchlistSaving.add(key));
    try {
      if (removing) {
        await _watchlistService.remove(
          stock.symbol,
          exchange: stock.exchange,
        );
      } else {
        await _watchlistService.add(stock.symbol, exchange: stock.exchange);
      }
      if (!mounted) return;
      setState(() {
        if (removing) {
          _watchlist.remove(key);
        } else {
          _watchlist.add(key);
        }
      });
      widget.onWatchlistChanged?.call();
    } on WatchlistException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update watchlist')),
      );
    } finally {
      if (mounted) setState(() => _watchlistSaving.remove(key));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      _generation++;
      setState(() {
        _results = widget.initialStocks;
        _loading = false;
        _failed = false;
      });
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await _marketData.searchSnapshot(
        query: query,
        pageSize: 100,
      );
      if (!mounted || generation != _generation) return;
      setState(() => _results = response.data);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      final needle = query.toLowerCase();
      setState(() {
        _failed = true;
        _results = widget.initialStocks
            .where(
              (stock) =>
                  stock.symbol.toLowerCase().contains(needle) ||
                  stock.name.toLowerCase().contains(needle),
            )
            .toList();
      });
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _select(StockQuote stock) {
    Navigator.pop(context);
    widget.onSelected(stock);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            hintText: 'Search symbol or company',
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_failed)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                'Live search is unavailable. Showing loaded instruments.',
                style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
              ),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No matching instruments found'))
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final stock = _results[index];
                      final key = WatchlistService.key(
                        stock.exchange,
                        stock.symbol,
                      );
                      return StockListTile(
                        stock: stock,
                        onTap: () => _select(stock),
                        isFavorite: _watchlist.contains(key),
                        onFavorite:
                            _watchlistLoading || _watchlistSaving.contains(key)
                            ? null
                            : () => _toggleWatchlist(stock),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
