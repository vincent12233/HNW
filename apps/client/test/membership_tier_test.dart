import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/l10n/app_language.dart';
import 'package:india_trading_app/widgets/membership_tier_badge.dart';

void main() {
  test('professional terms preserve product and order classifications', () {
    AppLanguage.instance.code = 'en';
    expect(tr('Transaction PIN'), 'Withdrawal PIN');
    expect(tr('Client Tier'), 'Membership Tier');
    expect(tr('Funds Ledger'), 'Account Ledger');
    expect(tr('Pending Orders'), 'Pending Orders');
    expect(tr('Institutional'), 'Institutional');
    expect(tr('OTC'), 'OTC');
    expect(tr('IPO'), 'IPO');
  });
  for (final language in ['en', 'hi']) {
    testWidgets(
      'membership icons and server tier updates fit narrow layouts in $language',
      (tester) async {
        AppLanguage.instance.code = language;
        for (final tier in [
          'STANDARD',
          'SILVER',
          'GOLD',
          'PLATINUM',
          'UNKNOWN',
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(1.4),
                    ),
                    child: SizedBox(
                      width: 82,
                      child: MembershipTierBadge(tier: tier),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.byType(Icon), findsOneWidget);
          expect(
            find.text(tier == 'UNKNOWN' ? '--' : tr(tier)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
        AppLanguage.instance.code = 'en';
      },
    );
  }
}
