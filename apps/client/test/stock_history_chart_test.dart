import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:k_chart/flutter_k_chart.dart';
import 'package:india_trading_app/widgets/professional_chart_canvas.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/models/market_history.dart';
import 'package:india_trading_app/widgets/stock_history_chart.dart';

MarketHistoryPoint point(int i, {double? price}) {
  final close = price ?? 100 + i.toDouble() + (i % 4 - 2);
  return MarketHistoryPoint(
    date: DateTime.utc(2026, 9, 10, 3, 45).add(Duration(minutes: i * 5)),
    open: close + 1,
    high: close + 3,
    low: close - 2,
    close: close,
    volume: 1000 + i * 20,
  );
}

MarketHistorySeries series(String range) => MarketHistorySeries(
  symbol: 'TEST',
  interval: range == '1D' ? '5m' : '1d',
  data: List.generate(80, (i) => point(i)),
  exchange: 'NSE',
  range: range,
  timezone: 'Asia/Kolkata',
);

void main() {
  test(
    'normalizes timestamps, duplicates and invalid bars without mutating source',
    () {
      final first = point(0);
      final invalid = MarketHistoryPoint(
        date: first.date,
        open: double.infinity,
        high: double.infinity,
        low: 1,
        close: 2,
        volume: 1,
      );
      final data = stockChartData([point(2), first, point(1), first, invalid]);
      expect(data.length, 3);
      expect(data.first.close, first.close);
      final date = DateTime.fromMillisecondsSinceEpoch(data.first.time!);
      expect(date.hour, 9);
      expect(date.minute, 15);
      expect(first.date.hour, 3);
      expect(data.last.time! > data.first.time!, isTrue);
    },
  );

  test('computes full-series indicators and handles flat prices', () {
    final data = stockChartData(series('1D').data);
    expect(data.last.maValueList!.length, 3);
    expect(data.last.rsi!.isFinite, isTrue);
    expect(data.last.macd!.isFinite, isTrue);
    final flat = stockChartData(List.generate(30, (i) => point(i, price: 100)));
    expect(flat.last.rsi == null || flat.last.rsi!.isFinite, isTrue);
  });

  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    StockHistoryLoader? loader,
    double latest = 180,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StockHistoryChart(
              symbol: 'TEST',
              exchange: 'NSE',
              latestPrice: latest,
              latestAt: DateTime.utc(2026, 9, 11),
              historyLoader:
                  loader ??
                  ({
                    required symbol,
                    required exchange,
                    required range,
                  }) async => series(range),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('chart and crosshair fit ${size.width} at large text', (
      tester,
    ) async {
      await mount(tester, size: size);
      expect(find.byType(ProfessionalChartCanvas), findsOneWidget);
      await tester.tapAt(
        tester.getTopLeft(find.byType(ProfessionalChartCanvas)) +
            const Offset(90, 80),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('quote snapshots do not overwrite historical OHLCV', (
    tester,
  ) async {
    await mount(tester);
    final before = tester
        .widget<ProfessionalChartCanvas>(find.byType(ProfessionalChartCanvas))
        .data
        .last
        .close;
    await mount(tester, latest: 500);
    expect(
      tester
          .widget<ProfessionalChartCanvas>(find.byType(ProfessionalChartCanvas))
          .data
          .last
          .close,
      before,
    );
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('range, indicators, volume and fullscreen are operable', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('1W'));
    await tester.pumpAndSettle();
    expect(find.text('1d · IST'), findsOneWidget);
    await tester.tap(find.byTooltip('Main indicator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BOLL (20, 2)'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProfessionalChartCanvas>(find.byType(ProfessionalChartCanvas))
          .mainState,
      MainState.BOLL,
    );
    await tester.tap(find.byTooltip('Volume'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ProfessionalChartCanvas>(find.byType(ProfessionalChartCanvas))
          .volHidden,
      isTrue,
    );
    await tester.tap(find.byTooltip('Full screen'));
    await tester.pumpAndSettle();
    expect(find.text('TEST · NSE'), findsOneWidget);
    expect(
      tester
          .widget<ProfessionalChartCanvas>(find.byType(ProfessionalChartCanvas))
          .mainState,
      MainState.BOLL,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('late range response cannot replace the current range', (
    tester,
  ) async {
    final pending = Completer<MarketHistorySeries>();
    await mount(
      tester,
      loader: ({required symbol, required exchange, required range}) {
        return range == '1W' ? pending.future : Future.value(series(range));
      },
    );
    await tester.tap(find.text('1W'));
    await tester.pump();
    await tester.tap(find.text('1M'));
    await tester.pumpAndSettle();
    pending.complete(series('1W'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'1M'},
    );
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('failed history can be retried', (tester) async {
    var fail = true;
    await mount(
      tester,
      loader: ({required symbol, required exchange, required range}) async {
        if (fail) throw StateError('offline');
        return series(range);
      },
    );
    expect(find.text('Unable to load price history'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfessionalChartCanvas), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('inspection reopens, pan and pinch update the viewport', (
    tester,
  ) async {
    await mount(tester);
    final chart = find.byType(ProfessionalChartCanvas);
    final target = tester.getTopLeft(chart) + const Offset(100, 150);
    await tester.tapAt(target);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tapAt(target);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.dragFrom(target, const Offset(90, 0));
    await tester.pumpAndSettle();
    final painted = find.descendant(
      of: chart,
      matching: find.byType(CustomPaint),
    );
    ChartPainter painter() =>
        tester.widget<CustomPaint>(painted.first).painter! as ChartPainter;
    expect(painter().scrollX, greaterThan(0));
    final a = await tester.startGesture(target, pointer: 1);
    final b = await tester.startGesture(
      target + const Offset(60, 0),
      pointer: 2,
    );
    await a.moveBy(const Offset(-25, 0));
    await b.moveBy(const Offset(25, 0));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(painter().scaleX, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('one candle and zero volume render with indicators', (
    tester,
  ) async {
    await mount(
      tester,
      loader: ({required symbol, required exchange, required range}) async =>
          MarketHistorySeries(
            symbol: symbol,
            interval: '5m',
            data: [
              MarketHistoryPoint(
                date: DateTime.utc(2026, 9, 10),
                open: 100,
                high: 100,
                low: 100,
                close: 100,
                volume: 0,
              ),
            ],
            exchange: exchange,
            range: range,
            timezone: 'Asia/Kolkata',
          ),
    );
    await tester.tap(find.byTooltip('Technical indicator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MACD (12, 26, 9)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  const output = String.fromEnvironment('CHART_CAPTURE_DIR');
  testWidgets('capture fixture chart', (tester) async {
    final font = File('C:/Windows/Fonts/arial.ttf');
    if (font.existsSync()) {
      for (final family in ['Roboto', 'Ahem', 'ahem', 'sans-serif', 'Arial']) {
        await (FontLoader(family)..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
    }
    final icons = File(
      'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
    await mount(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$output/chart.png'),
    );
    await tester.tap(find.byTooltip('Technical indicator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RSI (14)'));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getTopLeft(find.byType(ProfessionalChartCanvas)) +
          const Offset(120, 90),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('$output/chart-rsi.png'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }, skip: output.isEmpty);
}
