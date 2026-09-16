import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/announcements_service.dart';
import 'package:india_trading_app/services/app_client_settings_service.dart';
import 'package:india_trading_app/services/insight_articles_service.dart';

void main() {
  test('InsightArticle parses structured CMS payload', () {
    final article = InsightArticle.fromJson({
      'id': 'a1',
      'slug': 'account-and-kyc',
      'locale': 'en',
      'title': 'Account and KYC',
      'summary': 'Basics',
      'body': 'Register carefully',
      'imageUrl': null,
      'sortOrder': 1,
      'publishedAt': '2026-01-01T00:00:00.000Z',
    });
    expect(article.slug, 'account-and-kyc');
    expect(article.title, 'Account and KYC');
    expect(article.body, 'Register carefully');
    expect(article.sortOrder, 1);
  });

  test('AnnouncementItem parses public announcement payload', () {
    final item = AnnouncementItem.fromJson({
      'id': 'n1',
      'locale': 'en',
      'title': 'Maintenance',
      'body': 'Window tonight',
      'type': 'MAINTENANCE',
      'priority': 2,
      'sortOrder': 0,
      'startsAt': '2026-01-01T00:00:00.000Z',
      'endsAt': '2026-01-02T00:00:00.000Z',
    });
    expect(item.type, 'MAINTENANCE');
    expect(item.priority, 2);
    expect(item.startsAt, isNotNull);
  });

  test('AppClientSettings safe defaults never force-lock clients', () {
    expect(AppClientSettings.safeDefaults.forceUpdate, isFalse);
    expect(AppClientSettings.safeDefaults.maintenanceMode, isFalse);

    final parsed = AppClientSettings.fromJson({
      'platform': 'ANDROID',
      'minVersion': '1.0.0',
      'latestVersion': '1.2.0',
      'forceUpdate': true,
      'maintenanceMode': false,
      'maintenanceMessage': null,
      'supportUrl': 'https://example.com/support',
    });
    expect(parsed.platform, 'ANDROID');
    expect(parsed.forceUpdate, isTrue);
    expect(parsed.supportUrl, 'https://example.com/support');
  });
}
