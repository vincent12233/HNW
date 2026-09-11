import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/pages/notifications_page.dart';
import 'package:india_trading_app/services/client_account_service.dart';

class NotificationFake extends ClientAccountService {
  final read = Completer<void>();
  @override
  Future<List<Map<String, dynamic>>> notifications() async => [
    {'id': '1', 'title': 'Test notice', 'body': 'Test', 'readAt': null},
  ];
  @override
  Future<void> readNotification(String id) => read.future;
}

void main() {
  Finder button(String tooltip) => find.byWidgetPredicate(
    (widget) => widget is IconButton && widget.tooltip == tooltip,
  );
  testWidgets('refresh and bulk read are disabled during a single read', (
    tester,
  ) async {
    final service = NotificationFake();
    await tester.pumpWidget(
      MaterialApp(home: NotificationsPage(accountService: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test notice'));
    await tester.pump();
    expect(tester.widget<IconButton>(button('Refresh')).onPressed, isNull);
    expect(
      tester.widget<IconButton>(button('Mark all as read')).onPressed,
      isNull,
    );
    service.read.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mark all as read'), findsNothing);
    expect(tester.widget<IconButton>(button('Refresh')).onPressed, isNotNull);
  });
}
