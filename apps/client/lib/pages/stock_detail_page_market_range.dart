part of 'stock_detail_page.dart';

extension _StockDetailMarketRange on _StockDetailPageState {
  String _statPrice(double? value) => value == null ? '--' : formatPrice(value);

  double? get _yearHigh {
    final data = yearHistory?.data;
    if (data == null || data.isEmpty) return null;
    return data.map((point) => point.high).reduce((a, b) => a > b ? a : b);
  }

  double? get _yearLow {
    final data = yearHistory?.data;
    if (data == null || data.isEmpty) return null;
    return data.map((point) => point.low).reduce((a, b) => a < b ? a : b);
  }

  bool get _hasMarketRangeData =>
      (liveStock.high != null && liveStock.low != null) ||
      (_yearHigh != null && _yearLow != null);

  Widget _marketRangeCard() {
    final bid = liveStock.bid;
    final ask = liveStock.ask;
    final spread = bid != null && ask != null && ask >= bid ? ask - bid : null;
    final spreadPercent = spread != null && liveStock.price > 0
        ? spread / liveStock.price * 100
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'Market Snapshot',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            if (liveStock.low != null && liveStock.high != null) ...[
              const SizedBox(height: 16),
              _priceRange(
                label: "Day's Range",
                low: liveStock.low!,
                high: liveStock.high!,
                price: liveStock.price,
              ),
            ],
            if (_yearLow != null && _yearHigh != null) ...[
              const SizedBox(height: 18),
              _priceRange(
                label: '52-Week Range',
                low: _yearLow!,
                high: _yearHigh!,
                price: liveStock.price,
              ),
            ],
            if (spread != null) ...[
              const Divider(height: 28),
              Row(
                children: [
                  const Expanded(
                    child: AppText(
                      'Bid-Ask Spread',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                  AppText(
                    '${formatPrice(spread)}'
                    '${spreadPercent == null ? '' : ' (${spreadPercent.toStringAsFixed(3)}%)'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _priceRange({
    required String label,
    required double low,
    required double high,
    required double price,
  }) {
    final span = high - low;
    final position = span <= 0 ? 0.5 : ((price - low) / span).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            const markerSize = 12.0;
            final markerLeft =
                (constraints.maxWidth - markerSize) * position.toDouble();
            return SizedBox(
              height: 16,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Positioned(
                    left: markerLeft,
                    child: Container(
                      width: markerSize,
                      height: markerSize,
                      decoration: const BoxDecoration(
                        color: AppConfig.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Expanded(
              child: AppText(
                'Low ${formatPrice(low)}',
                style: const TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ),
            AppText(
              'High ${formatPrice(high)}',
              style: const TextStyle(color: Colors.black54, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
