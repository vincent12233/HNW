import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models/market_history.dart';
import '../services/market_data_service.dart';
import '../utils/number_formatters.dart';

class StockHistoryChart extends StatefulWidget {
  const StockHistoryChart({
    super.key,
    required this.symbol,
    required this.exchange,
    required this.latestPrice,
    required this.latestAt,
    this.previousClose,
  });
  final String symbol;
  final String exchange;
  final double latestPrice;
  final DateTime latestAt;
  final double? previousClose;

  @override
  State<StockHistoryChart> createState() => _StockHistoryChartState();
}

class _StockHistoryChartState extends State<StockHistoryChart> {
  final MarketDataService _marketData = MarketDataService();
  String _range = '1D';
  bool _loading = true;
  String? _error;
  List<MarketHistoryPoint> _points = <MarketHistoryPoint>[];
  List<MarketHistoryEvent> _events = <MarketHistoryEvent>[];
  int? _selectedIndex;
  int _loadGeneration = 0;
  bool _delayed = false;
  bool _candles = true;
  bool _movingAverages = true;
  String _indicator = 'NONE';

  MarketHistoryPoint? get _selectedPoint =>
      _selectedIndex == null || _selectedIndex! >= _points.length
      ? null
      : _points[_selectedIndex!];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StockHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.exchange != widget.exchange) {
      _range = '1D';
      _points = <MarketHistoryPoint>[];
      _events = <MarketHistoryEvent>[];
      _load();
      return;
    }
    if (oldWidget.latestPrice != widget.latestPrice ||
        oldWidget.latestAt != widget.latestAt) {
      _applyRealtimePrice();
    }
  }

  void _applyRealtimePrice() {
    if (_points.isEmpty || widget.latestPrice <= 0) return;
    final last = _points.last;
    final updated = MarketHistoryPoint(
      date: _range == '1D' ? widget.latestAt : last.date,
      open: last.open,
      high: widget.latestPrice > last.high ? widget.latestPrice : last.high,
      low: widget.latestPrice < last.low ? widget.latestPrice : last.low,
      close: widget.latestPrice,
      volume: last.volume,
    );
    setState(
      () => _points = <MarketHistoryPoint>[
        ..._points.take(_points.length - 1),
        updated,
      ],
    );
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final requestedRange = _range;
    final requestedSymbol = widget.symbol;
    final requestedExchange = widget.exchange;
    setState(() {
      _loading = true;
      _error = null;
      _selectedIndex = null;
      _delayed = false;
    });
    try {
      final series = await _marketData.fetchHistory(
        symbol: requestedSymbol,
        exchange: requestedExchange,
        range: requestedRange,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _points = series.data;
        _events = series.events;
        _delayed = series.delayed;
        _loading = false;
      });
      _applyRealtimePrice();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = 'Unable to load price history';
        _loading = false;
      });
    }
  }

  void _selectAt(Offset position, double width) {
    if (_points.length < 2 || width <= 0) return;
    final plotWidth = (width - 52).clamp(1.0, width).toDouble();
    final ratio = (position.dx / plotWidth).clamp(0.0, 1.0);
    final index = (ratio * (_points.length - 1)).round();
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedPoint;
    final first = _range == '1D' && widget.previousClose != null
        ? widget.previousClose
        : (_points.isEmpty ? null : _points.first.close);
    final last =
        selected?.close ?? (_points.isEmpty ? null : _points.last.close);
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
            if (_delayed) ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: Color(0xFFF59E0B)),
                  SizedBox(width: 5),
                  Text(
                    'Chart delayed',
                    style: TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
            if (_movingAverages && _points.isNotEmpty) ...[
              const SizedBox(height: 5),
              const Row(
                children: [
                  _ChartLegend(color: Color(0xFFF59E0B), label: 'MA5'),
                  SizedBox(width: 12),
                  _ChartLegend(color: Color(0xFF7C3AED), label: 'MA10'),
                  SizedBox(width: 12),
                  _ChartLegend(color: Color(0xFF0F766E), label: 'MA20'),
                ],
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedPointSummary(point: selected, range: _range),
            ],
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '1D', label: Text('1D')),
                      ButtonSegment(value: '1W', label: Text('1W')),
                      ButtonSegment(value: '1M', label: Text('1M')),
                      ButtonSegment(value: '3M', label: Text('3M')),
                      ButtonSegment(value: '6M', label: Text('6M')),
                      ButtonSegment(value: '1Y', label: Text('1Y')),
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
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Technical indicator',
                      initialValue: _indicator,
                      onSelected: (value) => setState(() => _indicator = value),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'NONE',
                          child: Text('No indicator'),
                        ),
                        PopupMenuItem(
                          value: 'BOLL',
                          child: Text('Bollinger Bands'),
                        ),
                        PopupMenuItem(value: 'RSI', child: Text('RSI (14)')),
                        PopupMenuItem(value: 'MACD', child: Text('MACD')),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.insights, size: 17),
                        label: Text(
                          _indicator == 'NONE' ? 'Indicators' : _indicator,
                        ),
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          icon: Icon(Icons.candlestick_chart, size: 17),
                          tooltip: 'Candles',
                        ),
                        ButtonSegment(
                          value: false,
                          icon: Icon(Icons.show_chart, size: 17),
                          tooltip: 'Line',
                        ),
                      ],
                      selected: {_candles},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) =>
                          setState(() => _candles = selection.first),
                    ),
                    FilterChip(
                      label: const Text('MA'),
                      selected: _movingAverages,
                      onSelected: (value) =>
                          setState(() => _movingAverages = value),
                    ),
                    IconButton(
                      tooltip: 'Full screen chart',
                      onPressed: _openFullScreen,
                      icon: const Icon(Icons.open_in_full, size: 20),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(height: 260, width: double.infinity, child: _chartBody()),
            if (_events.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Corporate actions',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: _events.map(_eventChip).toList(),
              ),
            ],
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
            range: _range,
            candles: _candles,
            movingAverages: _movingAverages,
            indicator: _indicator,
            events: _events,
            referencePrice: _range == '1D' && widget.previousClose != null
                ? widget.previousClose
                : _points.first.close,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _eventChip(MarketHistoryEvent event) {
    final ist = event.date.toUtc().add(const Duration(hours: 5, minutes: 30));
    final date =
        '${ist.day.toString().padLeft(2, '0')}/${ist.month.toString().padLeft(2, '0')}/${ist.year}';
    final detail = event.type == 'DIVIDEND'
        ? 'Dividend ${formatPrice(event.value)}'
        : event.label;
    return Chip(
      avatar: Icon(
        event.type == 'DIVIDEND'
            ? Icons.payments_outlined
            : Icons.call_split_rounded,
        size: 15,
      ),
      label: Text('$detail - $date'),
      visualDensity: VisualDensity.compact,
    );
  }

  void _openFullScreen() {
    if (_points.length < 2) return;
    final reference = _range == '1D' && widget.previousClose != null
        ? widget.previousClose
        : _points.first.close;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenHistoryChart(
          symbol: widget.symbol,
          points: _points,
          range: _range,
          candles: _candles,
          movingAverages: _movingAverages,
          indicator: _indicator,
          events: _events,
          referencePrice: reference,
        ),
      ),
    );
  }
}

class _FullScreenHistoryChart extends StatefulWidget {
  const _FullScreenHistoryChart({
    required this.symbol,
    required this.points,
    required this.range,
    required this.candles,
    required this.movingAverages,
    required this.indicator,
    required this.events,
    required this.referencePrice,
  });

  final String symbol;
  final List<MarketHistoryPoint> points;
  final String range;
  final bool candles;
  final bool movingAverages;
  final String indicator;
  final List<MarketHistoryEvent> events;
  final double referencePrice;

  @override
  State<_FullScreenHistoryChart> createState() =>
      _FullScreenHistoryChartState();
}

class _FullScreenHistoryChartState extends State<_FullScreenHistoryChart> {
  late int _visibleCount;
  int _startIndex = 0;
  int? _selectedIndex;
  int _gestureStartIndex = 0;
  int _gestureStartCount = 0;
  double _gestureStartX = 0;

  @override
  void initState() {
    super.initState();
    _visibleCount = widget.points.length;
  }

  List<MarketHistoryPoint> get _visiblePoints => widget.points
      .skip(_startIndex)
      .take(_visibleCount)
      .toList(growable: false);

  List<MarketHistoryEvent> get _visibleEvents {
    final visible = _visiblePoints;
    if (visible.isEmpty) return const <MarketHistoryEvent>[];
    final from = visible.first.date;
    final to = visible.last.date;
    return widget.events
        .where((event) => !event.date.isBefore(from) && !event.date.isAfter(to))
        .toList(growable: false);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartIndex = _startIndex;
    _gestureStartCount = _visibleCount;
    _gestureStartX = details.localFocalPoint.dx;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    if (width <= 0 || widget.points.length < 2) return;
    final minCount = math.min(20, widget.points.length);
    final nextCount = (_gestureStartCount / details.scale)
        .round()
        .clamp(minCount, widget.points.length)
        .toInt();
    final anchorRatio = (_gestureStartX / width).clamp(0.0, 1.0);
    final anchorIndex = _gestureStartIndex + anchorRatio * _gestureStartCount;
    final panPoints =
        (details.localFocalPoint.dx - _gestureStartX) / width * nextCount;
    final maxStart = widget.points.length - nextCount;
    final nextStart = (anchorIndex - anchorRatio * nextCount - panPoints)
        .round()
        .clamp(0, maxStart)
        .toInt();
    setState(() {
      _visibleCount = nextCount;
      _startIndex = nextStart;
      _selectedIndex = null;
    });
  }

  void _select(Offset position, double width) {
    final points = _visiblePoints;
    if (points.length < 2 || width <= 0) return;
    final plotWidth = (width - 52).clamp(1.0, width).toDouble();
    final ratio = (position.dx / plotWidth).clamp(0.0, 1.0);
    setState(() => _selectedIndex = (ratio * (points.length - 1)).round());
  }

  void _resetView() {
    setState(() {
      _startIndex = 0;
      _visibleCount = widget.points.length;
      _selectedIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final points = _visiblePoints;
    final events = _visibleEvents;
    final selected = _selectedIndex == null ? null : points[_selectedIndex!];
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.symbol} - ${widget.range}'),
        actions: [
          IconButton(
            tooltip: 'Reset zoom',
            onPressed: _visibleCount == widget.points.length
                ? null
                : _resetView,
            icon: const Icon(Icons.fit_screen_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              if (events.isNotEmpty) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _EventLegend(
                      color: Color(0xFF059669),
                      code: 'D',
                      label: 'Dividend',
                    ),
                    SizedBox(width: 12),
                    _EventLegend(
                      color: Color(0xFF2563EB),
                      code: 'S',
                      label: 'Split',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              SizedBox(
                height: 76,
                child: selected == null
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Long press the chart to inspect a candle',
                          style: TextStyle(color: Colors.black54, fontSize: 11),
                        ),
                      )
                    : SingleChildScrollView(
                        child: _SelectedPointSummary(
                          point: selected,
                          range: widget.range,
                        ),
                      ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: (details) =>
                        _onScaleUpdate(details, constraints.maxWidth),
                    onLongPressStart: (details) =>
                        _select(details.localPosition, constraints.maxWidth),
                    onLongPressMoveUpdate: (details) =>
                        _select(details.localPosition, constraints.maxWidth),
                    child: CustomPaint(
                      painter: _HistoryPainter(
                        points,
                        selectedIndex: _selectedIndex,
                        range: widget.range,
                        candles: widget.candles,
                        movingAverages: widget.movingAverages,
                        indicator: widget.indicator,
                        events: events,
                        referencePrice: widget.referencePrice,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pinch to zoom · drag to pan · long press to inspect',
                style: TextStyle(color: Colors.black54, fontSize: 11),
              ),
            ],
          ),
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
    final local = point.date.toUtc().add(const Duration(hours: 5, minutes: 30));
    final date =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    final stamp = range == '1D' || range == '1W' ? '$date $time' : date;
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

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 2, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 10),
        ),
      ],
    );
  }
}

class _EventLegend extends StatelessWidget {
  const _EventLegend({
    required this.color,
    required this.code,
    required this.label,
  });
  final Color color;
  final String code;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 8,
          backgroundColor: color,
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}

class _HistoryPainter extends CustomPainter {
  const _HistoryPainter(
    this.points, {
    this.selectedIndex,
    required this.range,
    required this.candles,
    required this.movingAverages,
    required this.indicator,
    required this.events,
    required this.referencePrice,
  });
  final List<MarketHistoryPoint> points;
  final int? selectedIndex;
  final String range;
  final bool candles;
  final bool movingAverages;
  final String indicator;
  final List<MarketHistoryEvent> events;
  final double? referencePrice;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width > 52 ? size.width - 52 : size.width;
    final priceHeight = size.height * 0.70;
    final volumeTop = size.height * 0.76;
    final volumeHeight = size.height * 0.14;
    final timeTop = size.height * 0.92;
    final closes = points.map((point) => point.close).toList();
    final minValue = candles
        ? points.map((point) => point.low).reduce((a, b) => a < b ? a : b)
        : closes.reduce((a, b) => a < b ? a : b);
    final maxValue = candles
        ? points.map((point) => point.high).reduce((a, b) => a > b ? a : b)
        : closes.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;

    final gridPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = priceHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(plotWidth, y), gridPaint);
    }

    final offsets = <Offset>[];
    final path = Path();
    for (var i = 0; i < closes.length; i++) {
      final x = candles
          ? plotWidth / points.length * i + plotWidth / points.length / 2
          : plotWidth * i / (closes.length - 1);
      final normalized = (closes[i] - minValue) / span;
      final y = priceHeight - normalized * (priceHeight - 12) - 6;
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

    if (candles) {
      _drawCandles(canvas, plotWidth, priceHeight, minValue, span);
    } else {
      final fillPath = Path.from(path)
        ..lineTo(plotWidth, priceHeight)
        ..lineTo(0, priceHeight)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [linePaint.color.withAlpha(48), linePaint.color.withAlpha(2)],
        ).createShader(Rect.fromLTWH(0, 0, plotWidth, priceHeight));
      canvas.drawPath(fillPath, fillPaint);
      canvas.drawPath(path, linePaint);
    }
    if (movingAverages) {
      _drawMovingAverage(
        canvas,
        plotWidth,
        priceHeight,
        minValue,
        span,
        5,
        const Color(0xFFF59E0B),
      );
      _drawMovingAverage(
        canvas,
        plotWidth,
        priceHeight,
        minValue,
        span,
        10,
        const Color(0xFF7C3AED),
      );
      _drawMovingAverage(
        canvas,
        plotWidth,
        priceHeight,
        minValue,
        span,
        20,
        const Color(0xFF0F766E),
      );
    }
    if (indicator == 'NONE' || indicator == 'BOLL') {
      _drawVolume(canvas, plotWidth, volumeTop, volumeHeight);
    }
    if (indicator == 'BOLL') {
      _drawBollingerBands(canvas, plotWidth, priceHeight, minValue, span);
    } else if (indicator == 'RSI') {
      _drawRsi(canvas, plotWidth, volumeTop, volumeHeight);
    } else if (indicator == 'MACD') {
      _drawMacd(canvas, plotWidth, volumeTop, volumeHeight);
    }
    _drawReferenceLine(canvas, plotWidth, priceHeight, minValue, span);
    _drawLastPrice(canvas, plotWidth, priceHeight, minValue, span);
    _drawExtremes(canvas, plotWidth, priceHeight, minValue, span);
    _drawCorporateActions(canvas, plotWidth, priceHeight);

    _drawPriceLabel(canvas, maxValue, plotWidth + 6, 0);
    _drawPriceLabel(
      canvas,
      minValue + span / 2,
      plotWidth + 6,
      priceHeight / 2 - 7,
    );
    _drawPriceLabel(canvas, minValue, plotWidth + 6, priceHeight - 14);
    _drawTimeLabel(canvas, points.first.date, 0, timeTop);
    _drawTimeLabel(
      canvas,
      points[points.length ~/ 2].date,
      plotWidth / 2,
      timeTop,
      centered: true,
    );
    _drawTimeLabel(
      canvas,
      points.last.date,
      plotWidth,
      timeTop,
      alignRight: true,
    );

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
        Offset(selected.dx, volumeTop + volumeHeight),
        crosshairPaint,
      );
      canvas.drawLine(
        Offset(0, selected.dy),
        Offset(plotWidth, selected.dy),
        crosshairPaint,
      );
      canvas.drawCircle(selected, 4.5, markerPaint);
      final haloPaint = Paint()..color = markerPaint.color.withAlpha(46);
      canvas.drawCircle(selected, 7, haloPaint);
      _drawSelectedPriceLabel(
        canvas,
        points[selectedIndex!].close,
        plotWidth,
        selected.dy,
        priceHeight,
      );
    }
  }

  void _drawReferenceLine(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
  ) {
    final reference = referencePrice;
    if (reference == null || reference <= 0) return;
    final y =
        priceHeight - ((reference - minValue) / span) * (priceHeight - 12) - 6;
    if (y < 0 || y > priceHeight) return;
    final paint = Paint()
      ..color = Colors.black26
      ..strokeWidth = 1;
    for (var x = 0.0; x < plotWidth; x += 6) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + 2).clamp(0.0, plotWidth).toDouble(), y),
        paint,
      );
    }
  }

  void _drawCorporateActions(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
  ) {
    if (events.isEmpty) return;
    final usedIndexes = <int, int>{};
    for (final event in events) {
      var nearestIndex = 0;
      var nearestDistance =
          (points.first.date.difference(event.date).inMilliseconds).abs();
      for (var index = 1; index < points.length; index++) {
        final distance =
            (points[index].date.difference(event.date).inMilliseconds).abs();
        if (distance < nearestDistance) {
          nearestIndex = index;
          nearestDistance = distance;
        }
      }
      final x = _pointX(nearestIndex, plotWidth);
      final level = usedIndexes.update(
        nearestIndex,
        (value) => value + 1,
        ifAbsent: () => 0,
      );
      final color = event.type == 'DIVIDEND'
          ? const Color(0xFF059669)
          : const Color(0xFF2563EB);
      final linePaint = Paint()
        ..color = color.withAlpha(95)
        ..strokeWidth = 1;
      for (var y = 22.0; y < priceHeight; y += 7) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, (y + 3).clamp(0.0, priceHeight).toDouble()),
          linePaint,
        );
      }
      final center = Offset(x, 11.0 + level * 20);
      canvas.drawCircle(center, 9, Paint()..color = color);
      final label = TextPainter(
        text: TextSpan(
          text: event.type == 'DIVIDEND' ? 'D' : 'S',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(center.dx - label.width / 2, center.dy - label.height / 2),
      );
    }
  }

  void _drawBollingerBands(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
  ) {
    const period = 20;
    if (points.length < period) return;
    final upper = Path();
    final middle = Path();
    final lower = Path();
    var started = false;
    for (var index = period - 1; index < points.length; index++) {
      final window = points
          .skip(index - period + 1)
          .take(period)
          .map((point) => point.close)
          .toList();
      final average = window.reduce((a, b) => a + b) / period;
      final variance =
          window
              .map((value) => math.pow(value - average, 2).toDouble())
              .reduce((a, b) => a + b) /
          period;
      final deviation = math.sqrt(variance);
      final x = _pointX(index, plotWidth);
      double y(double value) =>
          (priceHeight - ((value - minValue) / span) * (priceHeight - 12) - 6)
              .clamp(0.0, priceHeight)
              .toDouble();
      if (!started) {
        upper.moveTo(x, y(average + deviation * 2));
        middle.moveTo(x, y(average));
        lower.moveTo(x, y(average - deviation * 2));
        started = true;
      } else {
        upper.lineTo(x, y(average + deviation * 2));
        middle.lineTo(x, y(average));
        lower.lineTo(x, y(average - deviation * 2));
      }
    }
    final bandPaint = Paint()
      ..color = const Color(0xFF0284C7).withAlpha(180)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawPath(upper, bandPaint);
    canvas.drawPath(lower, bandPaint);
    canvas.drawPath(
      middle,
      Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    _drawIndicatorLabel(canvas, 'BOLL (20, 2)', volumeTop: priceHeight + 3);
  }

  void _drawRsi(Canvas canvas, double plotWidth, double top, double height) {
    const period = 14;
    if (points.length <= period) return;
    final values = <double?>[...List<double?>.filled(period, null)];
    for (var index = period; index < points.length; index++) {
      var gains = 0.0;
      var losses = 0.0;
      for (var offset = index - period + 1; offset <= index; offset++) {
        final change = points[offset].close - points[offset - 1].close;
        if (change >= 0) {
          gains += change;
        } else {
          losses -= change;
        }
      }
      final value = losses == 0 ? 100.0 : 100 - 100 / (1 + gains / losses);
      values.add(value);
    }
    double y(double value) => top + height - height * value / 100;
    final guide = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(70)), Offset(plotWidth, y(70)), guide);
    canvas.drawLine(Offset(0, y(30)), Offset(plotWidth, y(30)), guide);
    _drawNullableSeries(canvas, values, plotWidth, y, const Color(0xFF7C3AED));
    _drawIndicatorLabel(canvas, 'RSI 14   70 / 30', volumeTop: top - 11);
  }

  void _drawMacd(Canvas canvas, double plotWidth, double top, double height) {
    if (points.length < 26) return;
    final closes = points.map((point) => point.close).toList();
    final fast = _ema(closes, 12);
    final slow = _ema(closes, 26);
    final macd = List<double>.generate(
      closes.length,
      (index) => fast[index] - slow[index],
    );
    final signal = _ema(macd, 9);
    final all = [...macd, ...signal];
    final minValue = all.reduce((a, b) => a < b ? a : b);
    final maxValue = all.reduce((a, b) => a > b ? a : b);
    final rawSpan = (maxValue - minValue).abs();
    final span = rawSpan < 0.0001 ? 0.0001 : rawSpan;
    double y(double value) => top + height - (value - minValue) / span * height;
    final zeroY = y(0).clamp(top, top + height).toDouble();
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(plotWidth, zeroY),
      Paint()..color = Colors.black12,
    );
    final step = plotWidth / points.length;
    final barWidth = (step * 0.55).clamp(0.5, 6.0).toDouble();
    for (var index = 0; index < macd.length; index++) {
      final histogram = macd[index] - signal[index];
      final histogramY = y(histogram).clamp(top, top + height).toDouble();
      final x = _pointX(index, plotWidth);
      canvas.drawRect(
        Rect.fromLTRB(
          x - barWidth / 2,
          zeroY < histogramY ? zeroY : histogramY,
          x + barWidth / 2,
          zeroY > histogramY ? zeroY : histogramY,
        ),
        Paint()
          ..color = histogram >= 0
              ? AppConfig.gainColor.withAlpha(100)
              : AppConfig.lossColor.withAlpha(100),
      );
    }
    _drawSeries(canvas, macd, plotWidth, y, const Color(0xFF2563EB));
    _drawSeries(canvas, signal, plotWidth, y, const Color(0xFFF97316));
    _drawIndicatorLabel(canvas, 'MACD 12, 26, 9', volumeTop: top - 11);
  }

  List<double> _ema(List<double> values, int period) {
    final multiplier = 2 / (period + 1);
    final result = <double>[values.first];
    for (var index = 1; index < values.length; index++) {
      result.add((values[index] - result.last) * multiplier + result.last);
    }
    return result;
  }

  void _drawSeries(
    Canvas canvas,
    List<double> values,
    double plotWidth,
    double Function(double) y,
    Color color,
  ) {
    _drawNullableSeries(canvas, values, plotWidth, y, color);
  }

  void _drawNullableSeries(
    Canvas canvas,
    List<double?> values,
    double plotWidth,
    double Function(double) y,
    Color color,
  ) {
    final path = Path();
    var started = false;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value == null) continue;
      final x = _pointX(index, plotWidth);
      if (!started) {
        path.moveTo(x, y(value));
        started = true;
      } else {
        path.lineTo(x, y(value));
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
  }

  double _pointX(int index, double plotWidth) => candles
      ? plotWidth / points.length * index + plotWidth / points.length / 2
      : plotWidth * index / (points.length - 1);

  void _drawIndicatorLabel(
    Canvas canvas,
    String text, {
    required double volumeTop,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black54, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(0, volumeTop));
  }

  void _drawSelectedPriceLabel(
    Canvas canvas,
    double price,
    double plotWidth,
    double y,
    double priceHeight,
  ) {
    final label = TextPainter(
      text: TextSpan(
        text: price >= 1000
            ? price.toStringAsFixed(0)
            : price.toStringAsFixed(2),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 46);
    final top = (y - label.height / 2 - 3)
        .clamp(0.0, priceHeight - label.height - 6)
        .toDouble();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(plotWidth + 3, top, label.width + 8, label.height + 6),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF334155));
    label.paint(canvas, Offset(plotWidth + 7, top + 3));
  }

  void _drawMovingAverage(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
    int period,
    Color color,
  ) {
    if (points.length < period) return;
    final path = Path();
    var started = false;
    for (var index = period - 1; index < points.length; index++) {
      var total = 0.0;
      for (var offset = 0; offset < period; offset++) {
        total += points[index - offset].close;
      }
      final average = total / period;
      final x = candles
          ? plotWidth / points.length * index + plotWidth / points.length / 2
          : plotWidth * index / (points.length - 1);
      final y =
          priceHeight - ((average - minValue) / span) * (priceHeight - 12) - 6;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawExtremes(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
  ) {
    var highIndex = 0;
    var lowIndex = 0;
    for (var index = 1; index < points.length; index++) {
      if (points[index].high > points[highIndex].high) highIndex = index;
      if (points[index].low < points[lowIndex].low) lowIndex = index;
    }
    double x(int index) => candles
        ? plotWidth / points.length * index + plotWidth / points.length / 2
        : plotWidth * index / (points.length - 1);
    double y(double value) =>
        priceHeight - ((value - minValue) / span) * (priceHeight - 12) - 6;
    _drawMarkerLabel(
      canvas,
      'H ${points[highIndex].high.toStringAsFixed(2)}',
      x(highIndex),
      y(points[highIndex].high) - 15,
      plotWidth,
      priceHeight,
    );
    _drawMarkerLabel(
      canvas,
      'L ${points[lowIndex].low.toStringAsFixed(2)}',
      x(lowIndex),
      y(points[lowIndex].low) + 3,
      plotWidth,
      priceHeight,
    );
  }

  void _drawMarkerLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    double maxWidth,
    double maxHeight,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (x - painter.width / 2)
            .clamp(0.0, (maxWidth - painter.width).clamp(0.0, maxWidth))
            .toDouble(),
        y
            .clamp(0.0, (maxHeight - painter.height).clamp(0.0, maxHeight))
            .toDouble(),
      ),
    );
  }

  void _drawCandles(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
  ) {
    final step = plotWidth / points.length;
    final bodyWidth = (step * 0.62).clamp(0.6, 9.0).toDouble();
    double y(double value) =>
        priceHeight - ((value - minValue) / span) * (priceHeight - 12) - 6;
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final x = step * index + step / 2;
      final rising = point.close >= point.open;
      final color = rising ? AppConfig.gainColor : AppConfig.lossColor;
      final paint = Paint()..color = color;
      canvas.drawLine(Offset(x, y(point.high)), Offset(x, y(point.low)), paint);
      final top = y(rising ? point.close : point.open);
      final bottom = y(rising ? point.open : point.close);
      canvas.drawRect(
        Rect.fromLTRB(
          x - bodyWidth / 2,
          top,
          x + bodyWidth / 2,
          bottom <= top + 1 ? top + 1 : bottom,
        ),
        paint,
      );
    }
  }

  void _drawVolume(Canvas canvas, double plotWidth, double top, double height) {
    final maxVolume = points
        .map((point) => point.volume)
        .reduce((a, b) => a > b ? a : b);
    if (maxVolume <= 0) return;
    final step = plotWidth / points.length;
    final width = (step * 0.62).clamp(0.5, 8.0).toDouble();
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final barHeight = height * point.volume / maxVolume;
      final color = point.close >= point.open
          ? AppConfig.gainColor.withAlpha(100)
          : AppConfig.lossColor.withAlpha(100);
      final x = step * index + step / 2;
      canvas.drawRect(
        Rect.fromLTWH(
          x - width / 2,
          top + height - barHeight,
          width,
          barHeight,
        ),
        Paint()..color = color,
      );
    }
    if (points.length >= 5) {
      final path = Path();
      var started = false;
      for (var index = 4; index < points.length; index++) {
        var total = 0.0;
        for (var offset = 0; offset < 5; offset++) {
          total += points[index - offset].volume;
        }
        final average = total / 5;
        final x = step * index + step / 2;
        final y = top + height - height * average / maxVolume;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2563EB)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
      final label = TextPainter(
        text: const TextSpan(
          text: 'VOL MA5',
          style: TextStyle(color: Color(0xFF2563EB), fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, top - 10));
    }
  }

  void _drawLastPrice(
    Canvas canvas,
    double plotWidth,
    double priceHeight,
    double minValue,
    double span,
  ) {
    final last = points.last.close;
    final y = priceHeight - ((last - minValue) / span) * (priceHeight - 12) - 6;
    final color = points.last.close >= points.first.close
        ? AppConfig.gainColor
        : AppConfig.lossColor;
    final paint = Paint()
      ..color = color.withAlpha(130)
      ..strokeWidth = 1;
    const dash = 4.0;
    for (var x = 0.0; x < plotWidth; x += dash * 2) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dash).clamp(0, plotWidth).toDouble(), y),
        paint,
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text: last >= 1000 ? last.toStringAsFixed(0) : last.toStringAsFixed(2),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 48);
    label.paint(
      canvas,
      Offset(plotWidth + 5, (y - 6).clamp(0, priceHeight - 12).toDouble()),
    );
  }

  void _drawPriceLabel(Canvas canvas, double value, double x, double y) {
    final painter = TextPainter(
      text: TextSpan(
        text: value >= 1000
            ? value.toStringAsFixed(0)
            : value.toStringAsFixed(2),
        style: const TextStyle(color: Colors.black45, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 48);
    painter.paint(canvas, Offset(x, y));
  }

  void _drawTimeLabel(
    Canvas canvas,
    DateTime value,
    double x,
    double y, {
    bool alignRight = false,
    bool centered = false,
  }) {
    final ist = value.toUtc().add(const Duration(hours: 5, minutes: 30));
    final text = range == '1D'
        ? '${ist.hour.toString().padLeft(2, '0')}:${ist.minute.toString().padLeft(2, '0')}'
        : '${ist.day.toString().padLeft(2, '0')}/${ist.month.toString().padLeft(2, '0')}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black45, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        alignRight
            ? x - painter.width
            : centered
            ? x - painter.width / 2
            : x,
        y,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.range != range ||
      oldDelegate.candles != candles ||
      oldDelegate.movingAverages != movingAverages ||
      oldDelegate.indicator != indicator ||
      oldDelegate.events != events ||
      oldDelegate.referencePrice != referencePrice;
}
