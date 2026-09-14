import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/app_content_service.dart';

void main() {
  test('parses operable content bundle and deposit accounts', () {
    final bundle = AppContentBundle.fromJson({
      'home': {
        'banner.title': {'body': 'Live markets', 'locale': 'en'},
      },
      'deposit': {
        'instructions': {'body': 'Contact support', 'locale': 'en'},
        'receivingAccounts': [
          {
            'id': '1',
            'label': 'HDFC',
            'method': 'BANK',
            'accountNumber': '123',
          },
        ],
      },
      'support': {
        'greeting': {'body': 'Hello', 'locale': 'en'},
      },
      'trading': {
        'guide.ipo': {
          'title': 'IPO',
          'body': 'Apply carefully',
          'locale': 'en',
        },
      },
    });

    expect(bundle.text('home', 'banner.title'), 'Live markets');
    expect(bundle.text('deposit', 'instructions'), 'Contact support');
    expect(bundle.receivingAccounts.single.label, 'HDFC');
    expect(bundle.title('trading', 'guide.ipo'), 'IPO');
    expect(
      bundle.text('missing', 'x', fallback: 'fallback'),
      'fallback',
    );
  });
}
