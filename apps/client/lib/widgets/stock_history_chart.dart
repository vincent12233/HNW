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
              height: 190,
              width: double.infinity,
              child: _chartBody(),
            ),
            const SizedBox(height: 8),
            Text(
              selected == null
                  ? 'Drag across the chart to inspect OHLC and volume'
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
          Text(
            stamp,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
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
    if (volume >= 10000000) {
      return '${(volume / 10000000).toStringAsFixed(2)} Cr';
    }
    if (volume >= 100000) {
      return '${(volume / 100000).toStringAsFixed(2)} L';
    }
    if (volume >= 1000) return '${(volume / 1000).toStringAsFixed(1)} K';
    return '$volume';
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(this.points, {this.selectedIndex});
  final List<MarketHistoryPoint> points;
  final int? selectedIndex;

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

    final offsets = <Offset>[];
    final path = Path();
    for (var i = 0; i < closes.length; i++) {
      final x = size.width * i / (closes.length - 1);
      final normalized = (closes[i] - minValue) / span;
      final y = size.height - normalized * (size.height - 12) - 6;
      final offset = Offset(x, y);
      offsets.add(offset);
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

    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < offsets.length) {
      final selected = offsets[selectedIndex!];
      final markerPaint = Paint()..color = linePaint.color;
      final crosshairPaint = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(selected.dx, 0),
        Offset(selected.dx, size.height),
        crosshairPaint,
      );
      canvas.drawCircle(selected, 4.5, markerPaint);
      final haloPaint = Paint()..color = markerPaint.color.withAlpha(46);
      canvas.drawCircle(selected, 7, haloPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.selectedIndex != selectedIndex;
}
