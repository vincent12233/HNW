import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/app_content_service.dart';

void main() {
  test('parses operable content bundle including legal and insights', () {
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
      'legal': {
        'privacy.document': {
          'title': 'Privacy Policy',
          'body':
              '{"effective":"Effective now","sections":[{"heading":"1","body":"A"}]}',
        },
      },
      'about': {
        'company_name': {'body': 'India Trading App'},
      },
      'insights': {
        'article.01': {
          'title': 'Account and KYC',
          'body': 'Register carefully',
        },
      },
    });

    expect(bundle.text('home', 'banner.title'), 'Live markets');
    expect(bundle.receivingAccounts.single.label, 'HDFC');
    expect(bundle.privacyDocument().sections.single.heading, '1');
    expect(bundle.text('about', 'company_name'), 'India Trading App');
    expect(bundle.insightArticles().single.title, 'Account and KYC');
    expect(bundle.hasContent, isTrue);
  });
}
