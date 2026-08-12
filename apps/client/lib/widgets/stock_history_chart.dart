import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/market_history.dart';
import '../services/market_data_service.dart';
import '../utils/number_formatters.dart';

class StockHistoryChart extends StatefulWidget {
  const StockHistoryChart({super.key, required this.symbol});
  final String symbol;

  @override
  State<StockHistoryChart> createState() => _StockHistoryChartState();
}

class _StockHistoryChartState extends State<StockHistoryChart> {
  final MarketDataService _marketData = MarketDataService();
  String _range = '1D';
  bool _candles = false;
  bool _loading = true;
  String? _error;
  List<MarketHistoryPoint> _points = <MarketHistoryPoint>[];
  int? _selectedIndex;

  MarketHistoryPoint? get _selectedPoint =>
      _selectedIndex == null || _selectedIndex! >= _points.length
          ? null
          : _points[_selectedIndex!];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = null;
    });
    try {
      final series = await _marketData.fetchHistory(
        symbol: widget.symbol,
        range: _range,
      );
      if (!mounted) return;
      setState(() {
        _points = series.data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load price history';
        _loading = false;
      });
    }
  }

  void _selectAt(Offset position, double width) {
    if (_points.length < 2 || width <= 0) return;
    final ratio = (position.dx / width).clamp(0.0, 1.0);
    final index = (ratio * (_points.length - 1)).round();
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPoint;
    final first = _points.isEmpty ? null : _points.first.close;
    final last = selected?.close ?? (_points.isEmpty ? null : _points.last.close);
    final change = first == null || first <= 0 || last == null
        ? null
        : ((last - first) / first) * 100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Price History',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                if (last != null)
                  Text(
                    formatPrice(last),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            if (change != null) ...[
              const SizedBox(height: 4),
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: change >= 0
                      ? AppConfig.gainColor
                      : AppConfig.lossColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedPointSummary(point: selected, range: _range),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '1D', label: Text('1D')),
                      ButtonSegment(value: '1W', label: Text('1W')),
                      ButtonSegment(value: '1M', label: Text('1M')),
                    ],
                    selected: {_range},
                    onSelectionChanged: (selection) {
                      final next = selection.first;
                      if (next == _range) return;
                      setState(() => _range = next);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: _candles ? 'Line chart' : 'Candlestick chart',
                  onPressed: () => setState(() {
                    _candles = !_candles;
                    _selectedIndex = null;
                  }),
                  icon: Icon(
                    _candles
                        ? Icons.show_chart_rounded
                        : Icons.candlestick_chart_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 230,
              width: double.infinity,
              child: _chartBody(),
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? 'Tap or drag across the chart to inspect OHLC and volume'
                  : 'Tap or drag to inspect another point',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }
    if (_points.length < 2) {
      return const Center(child: Text('No history available'));
    }

    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) =>
            _selectAt(details.localPosition, constraints.maxWidth),
        onHorizontalDragStart: (details) =>
            _selectAt(details.localPosition, constraints.maxWidth),
        onHorizontalDragUpdate: (details) =>
            _selectAt(details.localPosition, constraints.maxWidth),
        child: CustomPaint(
          painter: _HistoryPainter(
            _points,
            selectedIndex: _selectedIndex,
            candles: _candles,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SelectedPointSummary extends StatelessWidget {
  const _SelectedPointSummary({required this.point, required this.range});
  final MarketHistoryPoint point;
  final String range;

  @override
  Widget build(BuildContext context) {
    final local = point.date.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final stamp = range == '1M' ? date : '$date $time';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stamp, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              Text('O ${formatPrice(point.open)}'),
              Text('H ${formatPrice(point.high)}'),
              Text('L ${formatPrice(point.low)}'),
              Text('C ${formatPrice(point.close)}'),
              Text('Vol ${_formatVolume(point.volume)}'),
            ],
          ),
        ],
      ),
    );
  }

  String _formatVolume(int volume) {
    if (volume >= 10000000) return '${(volume / 10000000).toStringAsFixed(2)} Cr';
    if (volume >= 100000) return '${(volume / 100000).toStringAsFixed(2)} L';
    if (volume >= 1000) return '${(volume / 1000).toStringAsFixed(1)} K';
    return '$volume';
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(
    this.points, {
    this.selectedIndex,
    required this.candles,
  });

  final List<MarketHistoryPoint> points;
  final int? selectedIndex;
  final bool candles;

  @override
  void paint(Canvas canvas, Size size) {
    const volumeHeight = 42.0;
    const gap = 10.0;
    final priceHeight = size.height - volumeHeight - gap;
    final lows = points.map((point) => point.low).toList();
    final highs = points.map((point) => point.high).toList();
    final minValue = lows.reduce((a, b) => a < b ? a : b);
    final maxValue = highs.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    final maxVolume = points
        .map((point) => point.volume)
        .fold<int>(0, (current, value) => value > current ? value : current);

    double yFor(double value) {
      final normalized = (value - minValue) / span;
      return priceHeight - normalized * (priceHeight - 12) - 6;
    }

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = priceHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    canvas.drawLine(
      Offset(0, priceHeight + gap / 2),
      Offset(size.width, priceHeight + gap / 2),
      gridPaint,
    );

    final step = size.width / points.length;
    final candleWidth = (step * 0.62).clamp(2.0, 12.0);
    final closeOffsets = <Offset>[];
    final closePath = Path();

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = step * i + step / 2;
      final closeOffset = Offset(x, yFor(point.close));
      closeOffsets.add(closeOffset);
      if (i == 0) {
        closePath.moveTo(closeOffset.dx, closeOffset.dy);
      } else {
        closePath.lineTo(closeOffset.dx, closeOffset.dy);
      }

      final rising = point.close >= point.open;
      final marketColor = rising ? AppConfig.gainColor : AppConfig.lossColor;
      final volumePaint = Paint()..color = marketColor.withAlpha(90);
      if (maxVolume > 0 && point.volume > 0) {
        final barHeight = volumeHeight * point.volume / maxVolume;
        canvas.drawRect(
          Rect.fromLTWH(
            x - candleWidth / 2,
            size.height - barHeight,
            candleWidth,
            barHeight,
          ),
          volumePaint,
        );
      }

      if (candles) {
        final wickPaint = Paint()
          ..color = marketColor
          ..strokeWidth = 1.2;
        canvas.drawLine(
          Offset(x, yFor(point.high)),
          Offset(x, yFor(point.low)),
          wickPaint,
        );
        final top = yFor(point.open > point.close ? point.open : point.close);
        final bottom = yFor(point.open < point.close ? point.open : point.close);
        final bodyHeight = (bottom - top).abs().clamp(1.5, priceHeight);
        final bodyPaint = Paint()..color = marketColor;
        canvas.drawRect(
          Rect.fromLTWH(x - candleWidth / 2, top, candleWidth, bodyHeight),
          bodyPaint,
        );
      }
    }

    if (!candles) {
      final positive = points.last.close >= points.first.close;
      final linePaint = Paint()
        ..color = positive ? AppConfig.gainColor : AppConfig.lossColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(closePath, linePaint);
    }

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < closeOffsets.length) {
      final selected = closeOffsets[selectedIndex!];
      final point = points[selectedIndex!];
      final markerColor = point.close >= point.open
          ? AppConfig.gainColor
          : AppConfig.lossColor;
      final crosshairPaint = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(selected.dx, 0),
        Offset(selected.dx, size.height),
        crosshairPaint,
      );
      canvas.drawCircle(selected, 4.5, Paint()..color = markerColor);
      canvas.drawCircle(
        selected,
        7,
        Paint()..color = markerColor.withAlpha(46),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.candles != candles;
}
