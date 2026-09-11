import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'professional_chart_canvas.dart';
import 'package:k_chart/flutter_k_chart.dart';

import '../l10n/app_language.dart';
import '../models/market_history.dart';
import '../services/market_data_service.dart';

typedef StockHistoryLoader =
    Future<MarketHistorySeries> Function({
      required String symbol,
      required String exchange,
      required String range,
    });

/// The chart package formats local dates. Adapt only its display timestamps to
/// exchange wall time; the original history timestamps remain unchanged.
List<KLineEntity> stockChartData(List<MarketHistoryPoint> points) {
  final unique = <int, MarketHistoryPoint>{
    for (final point in points)
      if (point.isValid) point.date.millisecondsSinceEpoch: point,
  };
  final ordered = unique.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final result = ordered.map((point) {
    final ist = point.date.toUtc().add(const Duration(hours: 5, minutes: 30));
    return KLineEntity.fromCustom(
      time: DateTime(
        ist.year,
        ist.month,
        ist.day,
        ist.hour,
        ist.minute,
      ).millisecondsSinceEpoch,
      open: point.open,
      high: point.high,
      low: point.low,
      close: point.close,
      vol: point.volume.toDouble(),
    );
  }).toList();
  if (result.isNotEmpty) DataUtil.calculate(result);
  return result;
}

class StockHistoryChart extends StatefulWidget {
  const StockHistoryChart({
    super.key,
    required this.symbol,
    required this.exchange,
    required this.latestPrice,
    required this.latestAt,
    this.previousClose,
    this.historyLoader,
    this.expanded = false,
    this.initialRange = '1D',
    this.initialMain = MainState.MA,
    this.initialSecondary = SecondaryState.NONE,
    this.initialLine = false,
    this.initialVolume = true,
  });

  final String symbol;
  final String exchange;
  final double latestPrice;
  final DateTime latestAt;
  final double? previousClose;
  final StockHistoryLoader? historyLoader;
  final bool expanded;
  final String initialRange;
  final MainState initialMain;
  final SecondaryState initialSecondary;
  final bool initialLine;
  final bool initialVolume;

  @override
  State<StockHistoryChart> createState() => _StockHistoryChartState();
}

class _StockHistoryChartState extends State<StockHistoryChart>
    with WidgetsBindingObserver {
  late String _range = widget.initialRange;
  late MainState _main = widget.initialMain;
  late SecondaryState _secondary = widget.initialSecondary;
  late bool _line = widget.initialLine;
  late bool _volume = widget.initialVolume;
  final _marketData = MarketDataService();
  List<KLineEntity> _data = [];
  MarketHistorySeries? _series;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _generation = 0;
  int _viewport = 0;
  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_foreground &&
          !_loading &&
          !_refreshing &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        _load(quiet: true);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void didUpdateWidget(covariant StockHistoryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.exchange != widget.exchange) {
      _range = '1D';
      _viewport++;
      _load();
    }
    // Live quote snapshots must never overwrite an historical OHLCV candle.
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final generation = ++_generation;
    setState(() {
      _error = null;
      _refreshing = quiet;
      _loading = !quiet;
      if (!quiet) {
        _data = [];
        _series = null;
      }
    });
    try {
      final series = await (widget.historyLoader ?? _marketData.fetchHistory)(
        symbol: widget.symbol,
        exchange: widget.exchange,
        range: _range,
      ).timeout(const Duration(seconds: 15));
      final data = stockChartData(series.data);
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _series = series;
        _loading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = 'Unable to load price history';
      });
    }
  }

  void _fullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${widget.symbol} · ${widget.exchange}')),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: StockHistoryChart(
                symbol: widget.symbol,
                exchange: widget.exchange,
                latestPrice: widget.latestPrice,
                latestAt: widget.latestAt,
                previousClose: widget.previousClose,
                historyLoader: widget.historyLoader,
                expanded: true,
                initialRange: _range,
                initialMain: _main,
                initialSecondary: _secondary,
                initialLine: _line,
                initialVolume: _volume,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = ChartColors()
      ..bgColor = [scheme.surface, scheme.surface]
      ..defaultTextColor = scheme.onSurfaceVariant
      ..gridColor = scheme.outlineVariant.withValues(alpha: .45)
      ..upColor = const Color(0xff00875a)
      ..dnColor = const Color(0xffd83948)
      ..nowPriceUpColor = const Color(0xff00875a)
      ..nowPriceDnColor = const Color(0xffd83948)
      ..kLineColor = scheme.primary
      ..lineFillColor = scheme.primary.withValues(alpha: .12)
      ..ma5Color = const Color(0xffb87800)
      ..ma10Color = const Color(0xff008c95)
      ..ma30Color = const Color(0xff7952bb)
      ..maxColor = scheme.onSurface
      ..minColor = scheme.onSurface
      ..selectFillColor = scheme.surface
      ..selectBorderColor = scheme.outline
      ..infoWindowNormalColor = scheme.onSurface
      ..infoWindowTitleColor = scheme.onSurfaceVariant
      ..infoWindowUpColor = const Color(0xff00875a)
      ..infoWindowDnColor = const Color(0xffd83948)
      ..hCrossColor = scheme.onSurfaceVariant
      ..vCrossColor = scheme.primary.withValues(alpha: .12)
      ..crossTextColor = scheme.onSurface;
    final style = ChartStyle()
      ..gridColumns = 3
      ..candleWidth = 7
      ..pointWidth = 10
      ..dateTimeFormat = (_series?.interval.endsWith('d') ?? false)
          ? [mm, '/', dd]
          : [HH, ':', nn];
    final last = _data.isEmpty ? null : _data.last;
    final height = widget.expanded
        ? (MediaQuery.sizeOf(context).height - 270).clamp(300.0, 900.0)
        : (_secondary == SecondaryState.NONE ? 320.0 : 410.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Price Chart',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: tr('Refresh'),
                onPressed: _loading || _refreshing
                    ? null
                    : () => _load(quiet: _data.isNotEmpty),
                icon: const Icon(Icons.refresh, size: 20),
              ),
              IconButton(
                tooltip: tr('Reset chart'),
                onPressed: () => setState(() => _viewport++),
                icon: const Icon(Icons.center_focus_strong, size: 20),
              ),
              if (!widget.expanded)
                IconButton(
                  tooltip: tr('Full screen'),
                  onPressed: _fullscreen,
                  icon: const Icon(Icons.fullscreen, size: 22),
                ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${widget.exchange} · INR',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (_series != null)
                Text(
                  '${_series!.interval} · IST',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (_series?.delayed == true || (_error != null && last != null))
                AppText(
                  'Chart delayed',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              if (_refreshing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final range in ['1D', '1W', '1M', '3M', '6M', '1Y'])
                  ButtonSegment(value: range, label: Text(range)),
              ],
              selected: {_range},
              onSelectionChanged: (value) {
                setState(() {
                  _range = value.single;
                  _viewport++;
                });
                _load();
              },
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: tr(_line ? 'Candlesticks' : 'Line chart'),
                isSelected: !_line,
                onPressed: () => setState(() => _line = !_line),
                icon: Icon(_line ? Icons.candlestick_chart : Icons.show_chart),
              ),
              PopupMenuButton<MainState>(
                tooltip: tr('Main indicator'),
                initialValue: _main,
                onSelected: (value) => setState(() => _main = value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: MainState.NONE,
                    child: AppText('No overlay'),
                  ),
                  const PopupMenuItem(
                    value: MainState.MA,
                    child: Text('MA (5, 10, 20)'),
                  ),
                  const PopupMenuItem(
                    value: MainState.BOLL,
                    child: Text('BOLL (20, 2)'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _main == MainState.NONE ? tr('No overlay') : _main.name,
                      ),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<SecondaryState>(
                tooltip: tr('Technical indicator'),
                initialValue: _secondary,
                onSelected: (value) => setState(() => _secondary = value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: SecondaryState.NONE,
                    child: AppText('No indicator'),
                  ),
                  const PopupMenuItem(
                    value: SecondaryState.RSI,
                    child: Text('RSI (14)'),
                  ),
                  const PopupMenuItem(
                    value: SecondaryState.MACD,
                    child: Text('MACD (12, 26, 9)'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_secondary == SecondaryState.NONE)
                        const Icon(Icons.query_stats, size: 20)
                      else
                        Text(_secondary.name),
                      const Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Volume'),
                isSelected: _volume,
                onPressed: () => setState(() => _volume = !_volume),
                icon: const Icon(Icons.bar_chart),
              ),
            ],
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final entry in {
                    'O': last.open,
                    'H': last.high,
                    'L': last.low,
                    'C': last.close,
                  }.entries)
                    Text(
                      '${entry.key} ${entry.value.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  Text(
                    'VOL ${last.vol.toInt()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          SizedBox(
            height: height,
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _data.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.candlestick_chart_outlined,
                          size: 32,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 12),
                        AppText(
                          _error ?? 'No price history available',
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const AppText('Retry'),
                        ),
                      ],
                    ),
                  )
                : ClipRect(
                    child: MediaQuery(
                      // The library paints fixed-size axis labels and tooltip rows.
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
                      child: KeyedSubtree(
                        key: ValueKey('${widget.symbol}:$_range:$_viewport'),
                        child: ProfessionalChartCanvas(
                          data: _data,
                          style: style,
                          colors: colors,
                          mainState: _main,
                          secondaryState: _secondary,
                          volHidden: !_volume,
                          isLine: _line,
                        ),
                      ),
                    ),
                  ),
          ),
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.fromMillisecondsSinceEpoch(last.time!))} IST',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ),
          if (_series?.events.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final event in _series!.events)
                    Chip(
                      avatar: Icon(
                        event.type == 'SPLIT'
                            ? Icons.call_split
                            : Icons.payments_outlined,
                        size: 16,
                      ),
                      label: Text(
                        '${event.date.toIso8601String().split('T').first} · ${event.label}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
