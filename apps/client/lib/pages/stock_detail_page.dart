import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/stock_quote.dart';
import '../models/trading_order.dart';
import '../services/market_socket_service.dart';
import '../services/trading_service.dart';
import '../services/watchlist_service.dart';
import '../utils/number_formatters.dart';
import '../widgets/stock_history_chart.dart';

class StockDetailPage extends StatefulWidget {
  const StockDetailPage({
    super.key,
    required this.stock,
    required this.onOrderPlaced,
  });

  final StockQuote stock;
  final Future<String?> Function(TradingOrder) onOrderPlaced;

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  final quantityController = TextEditingController(text: '1');
  final limitPriceController = TextEditingController();
  final marketSocket = MarketSocketService();
  final watchlistService = WatchlistService();

  late StockQuote liveStock;
  bool isBuy = true;
  bool isSubmitting = false;
  bool isWatched = false;
  bool watchlistLoading = true;
  bool watchlistSaving = false;
  String orderType = 'MARKET';
  String timeInForce = 'DAY';

  bool get isLimit => orderType == 'LIMIT';

  double get selectedOrderPrice {
    if (!isLimit) return liveStock.price;
    return double.tryParse(limitPriceController.text.trim()) ?? 0;
  }

  double get estimatedAmount {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    return quantity * selectedOrderPrice;
  }

  @override
  void initState() {
    super.initState();
    liveStock = widget.stock;
    limitPriceController.text = liveStock.price.toStringAsFixed(2);
    marketSocket.addQuoteListener(_handleQuoteUpdate);
    _loadWatchlistState();
  }

  Future<void> _loadWatchlistState() async {
    try {
      final symbols = await watchlistService.fetchSymbols();
      if (!mounted) return;
      setState(() {
        isWatched = symbols.contains(liveStock.symbol);
        watchlistLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => watchlistLoading = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    if (watchlistLoading || watchlistSaving) return;
    final next = !isWatched;
    setState(() {
      isWatched = next;
      watchlistSaving = true;
    });

    try {
      if (next) {
        await watchlistService.add(liveStock.symbol);
      } else {
        await watchlistService.remove(liveStock.symbol);
      }
      if (!mounted) return;
      setState(() => watchlistSaving = false);
      _showMessage(next ? 'Added to watchlist' : 'Removed from watchlist');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isWatched = !next;
        watchlistSaving = false;
      });
      _showMessage('Unable to update watchlist');
    }
  }

  double? _socketDouble(Map<String, dynamic> data, String key, double? fallback) {
    final value = double.tryParse(data[key]?.toString() ?? '');
    return value != null && value > 0 ? value : fallback;
  }

  void _handleQuoteUpdate(Map<String, dynamic> data) {
    final symbol = data['symbol']?.toString().trim().toUpperCase();
    if (symbol != liveStock.symbol) return;

    final price = double.tryParse(data['price']?.toString() ?? '');
    if (price == null || price <= 0 || !mounted) return;

    setState(() {
      liveStock = StockQuote(
        liveStock.symbol,
        liveStock.name,
        price,
        double.tryParse(data['change']?.toString() ?? '') ?? liveStock.change,
        int.tryParse(data['volume']?.toString() ?? '') ?? liveStock.volume,
        DateTime.tryParse(data['updatedAt']?.toString() ?? '') ?? DateTime.now(),
        logoUrl: liveStock.logoUrl,
        category: liveStock.category,
        previousClose: _socketDouble(data, 'previousClose', liveStock.previousClose),
        open: _socketDouble(data, 'open', liveStock.open),
        high: _socketDouble(data, 'high', liveStock.high),
        low: _socketDouble(data, 'low', liveStock.low),
        bid: _socketDouble(data, 'bid', liveStock.bid),
        ask: _socketDouble(data, 'ask', liveStock.ask),
      );
    });
  }

  @override
  void dispose() {
    marketSocket.removeQuoteListener(_handleQuoteUpdate);
    quantityController.dispose();
    limitPriceController.dispose();
    super.dispose();
  }

  void placeOrder() {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    final limitPrice = isLimit
        ? double.tryParse(limitPriceController.text.trim())
        : null;

    if (quantity <= 0) {
      _showMessage('Please enter a valid quantity');
      return;
    }
    if (isLimit && (limitPrice == null || limitPrice <= 0)) {
      _showMessage('Please enter a valid limit price');
      return;
    }

    final priceLabel = isLimit
        ? 'Limit price: ${formatPrice(limitPrice!)}'
        : 'Market price: ${formatPrice(liveStock.price)}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBuy ? 'Confirm Buy Order' : 'Confirm Sell Order'),
        content: Text(
          '${isBuy ? 'Buy' : 'Sell'} $quantity shares of ${liveStock.symbol}\n\n'
          '${isLimit ? 'Limit' : 'Market'} • $timeInForce\n'
          '$priceLabel\n\n'
          'Estimated amount: ${formatPrice(estimatedAmount)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setState(() => isSubmitting = true);
                    final order = TradingOrder(
                      symbol: liveStock.symbol,
                      isBuy: isBuy,
                      quantity: quantity,
                      price: liveStock.price,
                      placedAt: DateTime.now(),
                      type: orderType,
                      timeInForce: timeInForce,
                      limitPrice: limitPrice,
                    );

                    TradingService.clearLastPlacedOrder();
                    final errorMessage = await widget.onOrderPlaced(order);
                    final confirmedOrder = TradingService.takeLastPlacedOrder();

                    if (!mounted || !dialogContext.mounted) return;
                    setState(() => isSubmitting = false);

                    if (errorMessage != null) {
                      Navigator.pop(dialogContext);
                      _showMessage(errorMessage);
                      return;
                    }

                    Navigator.pop(dialogContext);
                    final message = confirmedOrder == null
                        ? '${isBuy ? 'Buy' : 'Sell'} ${isLimit ? 'limit' : 'market'} order submitted'
                        : orderResultMessage(confirmedOrder);
                    _showMessage(message, order: confirmedOrder);
                  },
            child: Text(isSubmitting ? 'Submitting...' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {TradingOrder? order}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: order == null
              ? null
              : SnackBarAction(
                  label: 'View Order',
                  onPressed: () => _showOrderDetails(order),
                ),
        ),
      );
  }

  void _showOrderDetails(TradingOrder order) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final price = order.averageFillPrice ?? order.limitPrice ?? order.price;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${order.symbol} Order',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(order.status.replaceAll('_', ' ')),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow('Side', order.isBuy ? 'BUY' : 'SELL'),
                _detailRow('Type', '${order.type} • ${order.timeInForce}'),
                _detailRow('Quantity', '${order.quantity}'),
                _detailRow('Filled', '${order.filledQuantity}'),
                _detailRow('Remaining', '${order.remainingQuantity}'),
                _detailRow('Price', price > 0 ? formatPrice(price) : '--'),
                if (order.orderId?.isNotEmpty == true)
                  _detailRow('Order ID', order.orderId!),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _statPrice(double? value) => value == null ? '--' : formatPrice(value);

  @override
  Widget build(BuildContext context) {
    final changeColor = liveStock.change > 0
        ? AppConfig.gainColor
        : liveStock.change < 0
            ? AppConfig.lossColor
            : AppConfig.neutralColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        title: Text(liveStock.symbol),
        actions: [
          IconButton(
            tooltip: isWatched ? 'Remove from watchlist' : 'Add to watchlist',
            onPressed: watchlistLoading || watchlistSaving ? null : _toggleWatchlist,
            icon: watchlistSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(isWatched ? Icons.star : Icons.star_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(liveStock.name),
                  const SizedBox(height: 12),
                  Text(
                    formatPrice(liveStock.price),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${liveStock.change > 0 ? '+' : ''}${liveStock.change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: changeColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StockHistoryChart(symbol: liveStock.symbol),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _marketStat('Bid', _statPrice(liveStock.bid))),
                      Expanded(child: _marketStat('Ask', _statPrice(liveStock.ask))),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: _marketStat('Open', _statPrice(liveStock.open))),
                      Expanded(
                        child: _marketStat(
                          'Prev. Close',
                          _statPrice(liveStock.previousClose),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(child: _marketStat('Day High', _statPrice(liveStock.high))),
                      Expanded(child: _marketStat('Day Low', _statPrice(liveStock.low))),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _marketStat('Volume', _formatVolume(liveStock.volume)),
                      ),
                      Expanded(child: _marketStat('Symbol', liveStock.symbol)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Place Order',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(value: true, label: Text('Buy')),
              ButtonSegment<bool>(value: false, label: Text('Sell')),
            ],
            selected: {isBuy},
            onSelectionChanged: (selection) => setState(() => isBuy = selection.first),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'MARKET', label: Text('Market')),
              ButtonSegment<String>(value: 'LIMIT', label: Text('Limit')),
            ],
            selected: {orderType},
            onSelectionChanged: (selection) {
              setState(() {
                orderType = selection.first;
                if (orderType == 'LIMIT' &&
                    limitPriceController.text.trim().isEmpty) {
                  limitPriceController.text = liveStock.price.toStringAsFixed(2);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          if (isLimit) ...[
            const SizedBox(height: 14),
            TextField(
              controller: limitPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Limit Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Validity', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['DAY', 'IOC', 'FOK']
                .map(
                  (value) => ChoiceChip(
                    label: Text(value),
                    selected: timeInForce == value,
                    onSelected: (_) => setState(() => timeInForce = value),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Estimated amount'),
              subtitle: Text(
                isLimit ? 'Based on limit price' : 'Based on current market price',
              ),
              trailing: Text(
                selectedOrderPrice > 0 ? formatPrice(estimatedAmount) : '--',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: placeOrder,
              style: FilledButton.styleFrom(
                backgroundColor: isBuy ? AppConfig.gainColor : AppConfig.lossColor,
              ),
              child: Text(isBuy ? 'Place Buy Order' : 'Place Sell Order'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(2)} Cr';
    }
    if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(2)} L';
    }
    if (volume >= 1000) {
      return '${(volume / 1000).toStringAsFixed(1)} K';
    }
    return '$volume';
  }
}

String orderResultMessage(TradingOrder order) {
  final filled = order.filledQuantity;
  final remaining = order.remainingQuantity;
  final fillPrice = order.averageFillPrice;
  final fillPriceText = fillPrice == null ? '' : ' • Avg. ${formatPrice(fillPrice)}';

  switch (order.status) {
    case 'FILLED':
      return 'Completed • Filled $filled/${order.quantity}$fillPriceText';
    case 'OPEN':
      return 'Order open • Filled $filled/${order.quantity} • Remaining $remaining';
    case 'PARTIALLY_FILLED':
      return 'Partially filled • Filled $filled/${order.quantity} • Remaining $remaining$fillPriceText';
    case 'CANCELLED':
      if (filled > 0) {
        return 'Partially filled • Filled $filled/${order.quantity} • Remaining $remaining cancelled$fillPriceText';
      }
      return 'Order cancelled • No shares filled';
    case 'REJECTED':
      final reason = order.rejectionReason?.trim();
      return reason == null || reason.isEmpty
          ? 'Order rejected'
          : 'Order rejected • $reason';
    case 'PENDING':
      return 'Order submitted';
    default:
      return 'Order ${order.status.toLowerCase().replaceAll('_', ' ')}';
  }
}
