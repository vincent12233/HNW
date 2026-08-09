import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/trading_order.dart';
import '../models/stock_quote.dart';
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

  bool isBuy = true;
  bool isSubmitting = false;

  double get estimatedAmount {
    final quantity = int.tryParse(quantityController.text) ?? 0;
    return quantity * widget.stock.price;
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  void placeOrder() {
    final quantity = int.tryParse(quantityController.text) ?? 0;

    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBuy ? 'Confirm Buy Order' : 'Confirm Sell Order'),
        content: Text(
          '${isBuy ? 'Buy' : 'Sell'} $quantity shares '
          'of ${widget.stock.symbol}\n\n'
          'Estimated amount: '
          '${formatPrice(estimatedAmount)}\n\n'
          'Your order will be processed securely '
          'will be used.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setState(() => isSubmitting = true);

                    final order = TradingOrder(
                      symbol: widget.stock.symbol,
                      isBuy: isBuy,
                      quantity: quantity,
                      price: widget.stock.price,
                      placedAt: DateTime.now(),
                    );

                    final errorMessage = await widget.onOrderPlaced(order);

                    if (!mounted || !dialogContext.mounted) {
                      return;
                    }

                    setState(() => isSubmitting = false);

                    if (errorMessage != null) {
                      Navigator.pop(dialogContext);

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(errorMessage)));

                      return;
                    }

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${isBuy ? 'Buy' : 'Sell'} order placed'),
                      ),
                    );
                  },
            child: Text(isSubmitting ? 'Submitting...' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final changeColor = widget.stock.change > 0
        ? AppConfig.gainColor
        : widget.stock.change < 0
        ? AppConfig.lossColor
        : AppConfig.neutralColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppConfig.primaryColor,
        foregroundColor: Colors.white,
        title: Text(widget.stock.symbol),
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
                  Text(widget.stock.name),
                  const SizedBox(height: 12),
                  Text(
                    formatPrice(widget.stock.price),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${widget.stock.change > 0 ? '+' : ''}'
                    '${widget.stock.change.toStringAsFixed(2)}%',
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
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Estimated amount'),
              trailing: Text(
                formatPrice(estimatedAmount),
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
