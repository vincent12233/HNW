import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/market_history.dart';
import '../services/market_data_service.dart';
import '../utils/number_formatters.dart';

class StockHistoryChart extends StatefulWidget {
  const StockHistoryChart({
    super.key,
    required this.symbol,
  });

  final String symbol;

  @override
  State<StockHistoryChart> createState() => _StockHistoryChartState();
}

class _StockHistoryChartState extends State<StockHistoryChart> {
  final MarketDataService _marketData = MarketDataService();
  String _range = '1D';
  bool _loading = true;
  String? _error;
  List<MarketHistoryPoint> _points = <MarketHistoryPoint>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
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

  @override
  Widget build(BuildContext context) {
    final first = _points.isEmpty ? null : _points.first.close;
    final last = _points.isEmpty ? null : _points.last.close;
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
                  color: change >= 0 ? AppConfig.gainColor : AppConfig.lossColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            SegmentedButton<String>(
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
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              width: double.infinity,
              child: _chartBody(),
            ),
            const SizedBox(height: 8),
            Text(
              _range == '1D'
                  ? 'Intraday • 5 min'
                  : _range == '1W'
                      ? 'Recent trading week • 1 hour'
                      : 'Recent month • daily',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chartBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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

    return CustomPaint(
      painter: _HistoryPainter(_points),
      child: const SizedBox.expand(),
    );
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.points);

  final List<MarketHistoryPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final closes = points.map((point) => point.close).toList();
    final minValue = closes.reduce((a, b) => a < b ? a : b);
    final maxValue = closes.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < closes.length; i++) {
      final x = closes.length == 1 ? 0.0 : size.width * i / (closes.length - 1);
      final normalized = (closes[i] - minValue) / span;
      final y = size.height - normalized * (size.height - 12) - 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final positive = closes.last >= closes.first;
    final linePaint = Paint()
      ..color = positive ? AppConfig.gainColor : AppConfig.lossColor
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
