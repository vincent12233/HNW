import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/theme/app_motion.dart';
import 'package:india_trading_app/theme/app_theme.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/utils/order_status_presentation.dart';
import 'package:india_trading_app/widgets/app_chip.dart';
import 'package:india_trading_app/widgets/app_feedback.dart';
import 'package:india_trading_app/widgets/app_page_scaffold.dart';
import 'package:india_trading_app/widgets/app_status_label.dart';
import 'package:india_trading_app/widgets/record_detail_sheet.dart';
import 'package:india_trading_app/widgets/trading/funds_tab.dart';
import 'package:india_trading_app/widgets/trading/orders_tab.dart';

Widget host(
  Widget child, {
  double textScale = 1,
  bool reduce = false,
  Size size = const Size(390, 844),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    builder: (context, content) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduce,
          accessibleNavigation: reduce,
        ),
        child: content!,
      );
    },
    home: Scaffold(body: child),
  );
}

void setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> dumpScreenshot(WidgetTester tester, String name) async {
  final dir = Directory('/tmp/hnw-j5-design-system');
  dir.createSync(recursive: true);
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  test('INR grouping preserves 0, negatives, and does not invent Unavailable as 0', () {
    expect(formatPrice(0).replaceAll(RegExp(r'[\s\u00a0\u202f]'), ''), '₹0.00');
    expect(formatPrice(1234567.8).replaceAll(RegExp(r'[\s\u00a0\u202f]'), ''), '₹12,34,567.80');
    expect(formatSignedPrice(-10), contains('₹'));
    expect(formatSignedPrice(-10), startsWith('-'));
    expect(formatAppDateTime(null), 'Unavailable');
    expect(
      formatAppDateTime(DateTime.fromMillisecondsSinceEpoch(0)),
      'Unavailable',
    );
  });

  test('IST formatter is shared and labeled', () {
    final stamp = DateTime.utc(2026, 9, 21, 10, 0);
    expect(formatIstDateTime(stamp), OrderStatusPresentation.formatIst(stamp));
    expect(formatIstDateTime(stamp), contains('IST'));
    expect(toIst(stamp).hour, 15);
    expect(toIst(stamp).minute, 30);
  });

  test('status mapping does not treat CREDIT/DEBIT as approval results', () {
    expect(chipVariantForStatus('APPROVED'), AppChipVariant.success);
    expect(chipVariantForStatus('REJECTED'), AppChipVariant.failed);
    expect(chipVariantForStatus('PENDING'), AppChipVariant.pending);
    expect(chipVariantForStatus('CANCELLED'), AppChipVariant.neutral);
    expect(chipVariantForStatus('CREDIT'), isNot(AppChipVariant.success));
    expect(chipVariantForStatus('CREDIT'), isNot(AppChipVariant.failed));
    expect(chipVariantForStatus('DEBIT'), isNot(AppChipVariant.success));
    expect(chipVariantForStatus('DEBIT'), isNot(AppChipVariant.failed));
    expect(displayStatusLabel(null), 'Unavailable');
    expect(displayStatusLabel(''), 'Unavailable');
    expect(displayStatusLabel('CREDIT'), 'Unavailable');
  });

  testWidgets('loading empty error retry stay distinct', (tester) async {
    setView(tester, const Size(390, 844));
    var retries = 0;
    await tester.pumpWidget(
      host(const AppLoadingView(message: 'Loading orders')),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No orders'), findsNothing);
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(
      host(
        const AppEmptyState(
          title: 'No orders',
          message: 'Your order activity will appear here. No sample orders are shown.',
        ),
      ),
    );
    expect(find.text('No orders'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsNothing);

    await tester.pumpWidget(
      host(
        AppErrorView(
          title: 'Orders could not be loaded',
          message: 'The last refresh failed. Your previous orders were not removed.',
          onRetry: () => retries++,
        ),
      ),
    );
    expect(find.text('Orders could not be loaded'), findsOneWidget);
    expect(find.text('No orders'), findsNothing);
    final retry = find.byType(OutlinedButton);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    expect(retries, 1);
  });

  testWidgets('text scale and widths do not overflow public states', (
    tester,
  ) async {
    for (final width in [320.0, 390.0, 414.0, 768.0]) {
      for (final scale in [1.0, 1.3, 1.5]) {
        setView(tester, Size(width, 844));
        await tester.pumpWidget(
          host(
            const AppEmptyState(
              title: 'No matching orders',
              message:
                  'Nothing in the currently loaded orders matches these filters.',
            ),
            textScale: scale,
            size: Size(width, 844),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('No matching orders'), findsOneWidget);
      }
    }
  });

  testWidgets('reduced motion uses the shared AppMotion entry', (tester) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(const AppLoadingView(message: 'Loading account activity'), reduce: true),
    );
    expect(AppMotion.reduce(tester.element(find.byType(AppLoadingView))), isTrue);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('status chips expose a text semantics label', (tester) async {
    await tester.pumpWidget(
      host(
        const AppLabeledStatus(status: 'PENDING'),
      ),
    );
    expect(find.bySemanticsLabel('Status PENDING'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
  });

  testWidgets('record sheet close target and Unavailable empty values', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showRecordDetailSheet(
              context,
              title: 'Deposit details',
              rows: const [('Amount', ''), ('Reference', 'DEP-1')],
            ),
            child: const Text('Open sheet'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('DEP-1'), findsOneWidget);
    final close = find.byTooltip('Close details');
    expect(tester.getSize(close).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.text('Deposit details'), findsNothing);
  });

  testWidgets('orders and funds tabs keep loading/error/retry callbacks', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    var orderRetries = 0;
    await tester.pumpWidget(
      host(const OrdersTab(orders: [], loading: true)),
    );
    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(
      host(
        OrdersTab(
          orders: const [],
          failed: true,
          onRefresh: () async {
            orderRetries++;
          },
        ),
      ),
    );
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('No orders'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(orderRetries, 1);

    var fundRetries = 0;
    await tester.pumpWidget(
      host(
        FundsTab(
          transactions: const [],
          loadFailed: true,
          onRefresh: () async {
            fundRetries++;
          },
        ),
      ),
    );
    expect(find.text('No fund transactions'), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(fundRetries, 1);
  });

  testWidgets('write component screenshots for J.5 visual review', (
    tester,
  ) async {
    setView(tester, const Size(390, 844));
    Future<void> capture(String name, Widget child, {bool reduce = false}) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: host(child, reduce: reduce),
        ),
      );
      await tester.pump();
      try {
        await dumpScreenshot(tester, name);
      } catch (_) {
        // Widget-test raster is environment-dependent; functional asserts still run.
      }
    }

    await capture(
      'client-loading-390',
      const AppLoadingView(message: 'Loading account activity'),
    );
    await capture(
      'client-empty-390',
      const AppEmptyState(
        title: 'No orders',
        message: 'Your order activity will appear here. No sample orders are shown.',
      ),
    );
    await capture(
      'client-error-390',
      AppErrorView(
        title: 'Orders could not be loaded',
        onRetry: () {},
      ),
    );
    await capture(
      'client-loading-reduced-motion',
      const AppLoadingView(message: 'Loading account activity'),
      reduce: true,
    );
    expect(find.byType(AppLoadingView), findsOneWidget);
  });
}
