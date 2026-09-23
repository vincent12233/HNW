import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/app_content_service.dart';

void main() {
  test('parses operable content bundle including legal and insights', () {
    final bundle = AppContentBundle.fromJson({
      'home': {
        'banner.title': {'body': 'Live markets', 'locale': 'en'},
        'ui.copy': {
          'body': '{"Retry":"Try again","Cancel":"Go back"}',
          'locale': 'en',
        },
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
        'risk.document': {
          'title': 'Risk Disclosure',
          'body':
              '{"effective":"Effective now","sections":[{"heading":"Risk","body":"Capital can be lost"}]}',
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
    expect(bundle.uiCopy(), {'Retry': 'Try again', 'Cancel': 'Go back'});
    expect(bundle.text('deposit', 'instructions'), 'Contact support');
    expect(
      bundle.text('support', 'hours'),
      'Online customer service hours: Mon-Sun 09:00-22:00 (IST).',
    );
    expect(bundle.privacyDocument().sections.single.heading, '1');
    expect(bundle.riskDocument().sections.single.body, 'Capital can be lost');
    expect(bundle.text('about', 'company_name'), 'India Trading App');
    expect(bundle.hasContent, isTrue);
  });

  test(
    'keeps malformed legal content visible as a readable fallback block',
    () {
      final bundle = AppContentBundle.fromJson({
        'legal': {
          'terms.document': {
            'title': 'Terms of Service',
            'body': 'Legacy terms text that is still readable',
            'locale': 'en',
          },
        },
      });

      final document = bundle.termsDocument();
      expect(document.effective, isEmpty);
      expect(document.title, 'Terms of Service');
      expect(document.sections.single.heading, 'Terms of Service');
      expect(
        document.sections.single.body,
        'Legacy terms text that is still readable',
      );
    },
  );

  test('ignores malformed global UI copy', () {
    final bundle = AppContentBundle.fromJson({
      'home': {
        'ui.copy': {'body': 'not-json', 'locale': 'en'},
      },
    });
    expect(bundle.uiCopy(), isEmpty);
  });
}
