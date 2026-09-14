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
      },
      'support': {
        'greeting': {'body': 'Hello', 'locale': 'en'},
        'hours': {
          'body': 'Online customer service hours: Mon-Sun 09:00-22:00 (IST).',
          'locale': 'en',
        },
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
    expect(bundle.text('deposit', 'instructions'), 'Contact support');
    expect(
      bundle.text('support', 'hours'),
      'Online customer service hours: Mon-Sun 09:00-22:00 (IST).',
    );
    expect(bundle.privacyDocument().sections.single.heading, '1');
    expect(bundle.text('about', 'company_name'), 'India Trading App');
    expect(bundle.insightArticles().single.title, 'Account and KYC');
    expect(bundle.hasContent, isTrue);
  });
}
