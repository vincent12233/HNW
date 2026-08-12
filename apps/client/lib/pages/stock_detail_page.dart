import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
import '../services/market_socket_service.dart';
import '../services/trading_service.dart';
import '../utils/number_formatters.dart';

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

  late StockQuote liveStock;
  bool isBuy = true;
  bool isSubmitting = false;
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
                    _showMessage(
                      confirmedOrder == null
                          ? '${isBuy ? 'Buy' : 'Sell'} ${isLimit ? 'limit' : 'market'} order submitted'
                          : orderResultMessage(confirmedOrder),
                    );
                  },
            child: Text(isSubmitting ? 'Submitting...' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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
            onSelectionChanged: (selection) {
              setState(() => isBuy = selection.first);
            },
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
          const Text(
            'Validity',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
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
                backgroundColor: isBuy
                    ? AppConfig.gainColor
                    : AppConfig.lossColor,
              ),
              child: Text(isBuy ? 'Place Buy Order' : 'Place Sell Order'),
            ),
          ),
        ],
      ),
    );
  }
}

String orderResultMessage(TradingOrder order) {
  final filled = order.filledQuantity;
  final remaining = order.remainingQuantity;
  final fillPrice = order.averageFillPrice;
  final fillPriceText = fillPrice == null
      ? ''
      : ' • Avg. ${formatPrice(fillPrice)}';

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
