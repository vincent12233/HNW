import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:k_chart/flutter_k_chart.dart';
import '../l10n/app_language.dart';

/// Uses k_chart's full-series renderer with responsive inspection controls.
class ProfessionalChartCanvas extends StatefulWidget {
  const ProfessionalChartCanvas({
    super.key,
    required this.data,
    required this.style,
    required this.colors,
    required this.mainState,
    required this.secondaryState,
    required this.volHidden,
    required this.isLine,
  });
  final List<KLineEntity> data;
  final ChartStyle style;
  final ChartColors colors;
  final MainState mainState;
  final SecondaryState secondaryState;
  final bool volHidden;
  final bool isLine;
  @override
  State<ProfessionalChartCanvas> createState() =>
      _ProfessionalChartCanvasState();
}

class _ProfessionalChartCanvasState extends State<ProfessionalChartCanvas> {
  final _selection = StreamController<InfoWindowEntity?>.broadcast();
  late final Stream<InfoWindowEntity?> _distinctSelection = _selection.stream
      .distinct((a, b) => a?.kLineEntity == b?.kLineEntity);
  double _scale = 1;
  double _startScale = 1;
  double _scroll = 0;
  double? _selectedX;
  double _width = 0;
  double get _maxScroll => math.max(
    0,
    widget.data.length * widget.style.pointWidth -
        _width / _scale +
        widget.style.pointWidth / 2 +
        24,
  );
  void _select(Offset position) => setState(() => _selectedX = position.dx);
  @override
  void dispose() {
    _selection.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _width = constraints.maxWidth;
      _scroll = _scroll.clamp(0, _maxScroll);
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _select(details.localPosition),
              onLongPressStart: (details) => _select(details.localPosition),
              onLongPressMoveUpdate: (details) =>
                  _select(details.localPosition),
              onScaleStart: (_) {
                _startScale = _scale;
              },
              onScaleUpdate: (details) => setState(() {
                _selectedX = null;
                _scale = (_startScale * details.scale).clamp(.5, 3);
                _scroll = (_scroll + details.focalPointDelta.dx / _scale).clamp(
                  0,
                  _maxScroll,
                );
              }),
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ChartPainter(
                    widget.style,
                    widget.colors,
                    lines: [],
                    isTrendLine: false,
                    selectY: 0,
                    datas: widget.data,
                    scaleX: _scale,
                    scrollX: _scroll,
                    selectX: _selectedX ?? 0.0,
                    isLongPass: _selectedX != null,
                    isOnTap: false,
                    isTapShowInfoDialog: true,
                    xFrontPadding: 24.0,
                    verticalTextAlignment: VerticalTextAlignment.right,
                    mainState: widget.mainState,
                    secondaryState: widget.secondaryState,
                    volHidden: widget.volHidden,
                    isLine: widget.isLine,
                    sink: _selection.sink,
                  ),
                ),
              ),
            ),
          ),
          if (_selectedX != null)
            Positioned(
              top: 32,
              left: 8,
              right: 8,
              child: StreamBuilder<InfoWindowEntity?>(
                stream: _distinctSelection,
                builder: (context, snapshot) {
                  final candle = snapshot.data?.kLineEntity;
                  if (candle == null) return const SizedBox();
                  return Material(
                    color: widget.colors.selectFillColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(color: widget.colors.selectBorderColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${DateFormat('dd MMM yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(candle.time!))} IST',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: tr('Close'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    setState(() => _selectedX = null),
                                icon: const Icon(Icons.close, size: 16),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 14,
                            runSpacing: 6,
                            children: [
                              for (final item in {
                                'Open': candle.open,
                                'High': candle.high,
                                'Low': candle.low,
                                'Close': candle.close,
                              }.entries)
                                Text(
                                  '${tr(item.key)} ${item.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              Text(
                                '${tr('Volume')} ${candle.vol.toInt()}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
