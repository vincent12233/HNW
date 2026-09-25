import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/stock_quote.dart';
import 'package:india_trading_app/utils/number_formatters.dart';
import 'package:india_trading_app/widgets/app_feedback.dart';
import 'package:india_trading_app/widgets/home/home_action_button.dart';
import 'package:india_trading_app/widgets/market_header.dart';
import 'package:india_trading_app/widgets/profile_menu.dart';
import 'package:india_trading_app/widgets/stock_list_tile.dart';
import 'package:india_trading_app/widgets/floating_support_button.dart';
import 'package:india_trading_app/theme/app_colors.dart';

Widget host(Widget child, {double textScale = 1, bool reduceMotion = false}) =>
    MaterialApp(
      builder: (context, content) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
          accessibleNavigation: reduceMotion,
        ),
        child: content!,
      ),
      home: Scaffold(body: child),
    );

void smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('support button honors reduced motion on first frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(FloatingSupportButton(onTap: () {}), reduceMotion: true),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(FloatingSupportButton), findsOneWidget);
  });

  testWidgets(
    'quote values fit large text and favorite does not open details',
    (tester) async {
      smallPhone(tester);
      var detailsOpened = 0;
      var favoritesChanged = 0;
      final stock = StockQuote(
        'HINDUNILVR',
        'Hindustan Unilever Limited',
        123456.78,
        -12.34,
        10,
        DateTime(2026),
        quoteFresh: false,
      );
      await tester.pumpWidget(
        host(
          StockListTile(
            stock: stock,
            onTap: () => detailsOpened++,
            onFavorite: () => favoritesChanged++,
          ),
          textScale: 2,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(formatPrice(stock.price)), findsOneWidget);
      expect(find.byTooltip('Delayed quote'), findsOneWidget);
      final favorite = find.byTooltip('Add to watchlist');
      expect(tester.getSize(favorite).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(favorite).height, greaterThanOrEqualTo(48));
      await tester.tap(favorite);
      expect(favoritesChanged, 1);
      expect(detailsOpened, 0);
      await tester.tap(find.text('HINDUNILVR'));
      expect(detailsOpened, 1);
    },
  );

  testWidgets('narrow action cards keep complete action labels and callbacks', (
    tester,
  ) async {
    smallPhone(tester);
    var tapped = false;
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: SizedBox(
            width: 144,
            child: HomeActionButton(
              label: 'Withdraw Funds',
              subtitle: 'Transfer to Bank',
              icon: Icons.call_made_rounded,
              color: Colors.green,
              onTap: () => tapped = true,
            ),
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(find.text('Withdraw Funds'));
    expect(label.maxLines, isNull);
    expect(label.overflow, isNot(TextOverflow.ellipsis));
    await tester.tap(find.text('Withdraw Funds'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'profile verification status remains readable without navigation',
    (tester) async {
      smallPhone(tester);
      await tester.pumpWidget(
        host(
          const ProfileMenuRow(
            icon: Icons.verified_user_outlined,
            title: 'KYC Verification',
            subtitle: 'Identity documents and verification status',
            status: 'Verified',
          ),
          textScale: 2,
        ),
      );
      expect(find.text('Verified'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.verified_user_outlined),
      );
      expect(icon.color, AppColors.textInverse);
      final title = tester.getRect(find.text('KYC Verification'));
      final status = tester.getRect(find.text('Verified'));
      expect(status.left, greaterThan(title.left));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('notification badge passes taps to its button at large text', (
    tester,
  ) async {
    smallPhone(tester);
    var notificationsOpened = 0;
    var searchOpened = 0;
    await tester.pumpWidget(
      host(
        MarketHeader(
          accountName: 'A very long account name',
          notificationCount: 25,
          onNotificationTap: () => notificationsOpened++,
          onSearchTap: () => searchOpened++,
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Notifications (25)'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('9+')));
    expect(notificationsOpened, 1);
    final search = find.byTooltip('Search stocks');
    await tester.tap(search);
    expect(searchOpened, 1);
  });

  testWidgets('loading message scrolls within a short viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          height: 96,
          child: AppLoadingView(
            message: 'Loading your account and latest market information',
          ),
        ),
        textScale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('retry target is accessible and invokes the supplied action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      host(
        AppErrorView(title: 'Unable to load account', onRetry: () => retries++),
      ),
    );
    final retry = find.byType(OutlinedButton);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    expect(retries, 1);
  });
}
