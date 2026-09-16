import 'package:flutter_test/flutter_test.dart';

import 'package:india_trading_app/services/app_client_settings_service.dart';
import 'package:india_trading_app/services/app_version.dart';
import 'package:india_trading_app/services/announcements_service.dart';
import 'package:india_trading_app/widgets/home_announcement_banner.dart';

void main() {
  group('AppVersion', () {
    test('parses and compares semantic versions', () {
      expect(
        AppVersion.tryParse('1.10.0')!.compareTo(AppVersion.tryParse('1.2.0')!),
        greaterThan(0),
      );
      expect(
        AppVersion.tryParse('2.0.0')!.compareTo(AppVersion.tryParse('1.9.9')!),
        greaterThan(0),
      );
      expect(
        AppVersion.tryParse('1.2.3')!.compareTo(AppVersion.tryParse('1.2.3')!),
        0,
      );
    });

    test('rejects invalid versions', () {
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('resolveAppSettingsGate', () {
    test('force update when below min and flag set', () {
      expect(
        resolveAppSettingsGate(
          currentVersion: '1.0.0',
          minVersion: '1.1.0',
          latestVersion: '1.2.0',
          forceUpdate: true,
          maintenanceMode: true,
        ),
        AppSettingsGate.forceUpdate,
      );
    });

    test('maintenance when not forcing update', () {
      expect(
        resolveAppSettingsGate(
          currentVersion: '1.2.0',
          minVersion: '1.0.0',
          latestVersion: '1.2.0',
          forceUpdate: true,
          maintenanceMode: true,
        ),
        AppSettingsGate.maintenance,
      );
    });

    test('optional update when below latest only', () {
      expect(
        resolveAppSettingsGate(
          currentVersion: '1.1.0',
          minVersion: '1.0.0',
          latestVersion: '1.2.0',
          forceUpdate: false,
          maintenanceMode: false,
        ),
        AppSettingsGate.optionalUpdate,
      );
    });

    test('invalid current version never locks', () {
      expect(
        resolveAppSettingsGate(
          currentVersion: 'bad',
          minVersion: '9.0.0',
          latestVersion: '9.0.0',
          forceUpdate: true,
          maintenanceMode: true,
        ),
        AppSettingsGate.none,
      );
    });

    test('safe defaults never force or maintain', () {
      expect(AppClientSettings.safeDefaults.forceUpdate, isFalse);
      expect(AppClientSettings.safeDefaults.maintenanceMode, isFalse);
    });
  });

  group('pickTopAnnouncement', () {
    test('returns null when empty', () {
      expect(pickTopAnnouncement(const []), isNull);
    });

    test('prefers higher priority live item', () {
      final now = DateTime.now();
      final items = [
        AnnouncementItem(
          id: '1',
          locale: 'en',
          title: 'Low',
          body: 'a',
          type: 'GENERAL',
          priority: 1,
          sortOrder: 0,
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 1)),
        ),
        AnnouncementItem(
          id: '2',
          locale: 'en',
          title: 'High',
          body: 'b',
          type: 'IMPORTANT',
          priority: 5,
          sortOrder: 1,
          startsAt: now.subtract(const Duration(hours: 1)),
          endsAt: now.add(const Duration(hours: 1)),
        ),
      ];
      expect(pickTopAnnouncement(items)!.title, 'High');
    });

    test('skips expired announcements', () {
      final now = DateTime.now();
      final items = [
        AnnouncementItem(
          id: '1',
          locale: 'en',
          title: 'Old',
          body: 'a',
          type: 'GENERAL',
          priority: 9,
          endsAt: now.subtract(const Duration(minutes: 1)),
        ),
      ];
      expect(pickTopAnnouncement(items), isNull);
    });
  });

  group('AppClientSettingsService injection', () {
    test('applyForTest updates gate and dismisses optional update', () {
      final service = AppClientSettingsService.instance;
      service.applyForTest(
        settings: const AppClientSettings(
          platform: 'ANDROID',
          minVersion: '1.0.0',
          latestVersion: '2.0.0',
          forceUpdate: false,
          maintenanceMode: false,
        ),
        currentVersion: '1.5.0',
      );
      expect(service.gate, AppSettingsGate.optionalUpdate);
      service.dismissOptionalUpdate();
      expect(service.gate, AppSettingsGate.none);
      expect(service.optionalUpdateDismissed, isTrue);

      // Restore safe defaults for other tests.
      service.applyForTest(
        settings: AppClientSettings.safeDefaults,
        currentVersion: '1.0.5',
        optionalDismissed: false,
      );
    });
  });

  group('parseValidUpdateUrl', () {
    test('accepts Android Play Store https URL', () {
      final uri = parseValidUpdateUrl(
        'https://play.google.com/store/apps/details?id=com.example.hnw',
      );
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'play.google.com');
    });

    test('accepts iOS App Store https URL', () {
      final uri = parseValidUpdateUrl('https://apps.apple.com/app/id123456');
      expect(uri, isNotNull);
      expect(uri!.host, 'apps.apple.com');
    });

    test('missing URL is safe null', () {
      expect(parseValidUpdateUrl(null), isNull);
      expect(parseValidUpdateUrl(''), isNull);
      expect(parseValidUpdateUrl('   '), isNull);
    });

    test('invalid URL rejected', () {
      expect(parseValidUpdateUrl('not-a-url'), isNull);
      expect(parseValidUpdateUrl('ftp://example.com/app'), isNull);
      expect(parseValidUpdateUrl('javascript:alert(1)'), isNull);
      expect(parseValidUpdateUrl('/relative/path'), isNull);
    });
  });

  group('force update with updateUrl', () {
    tearDown(() {
      AppClientSettingsService.instance.applyForTest(
        settings: AppClientSettings.safeDefaults,
        currentVersion: '1.0.5',
      );
    });

    test('force update with valid URL keeps force gate', () {
      final service = AppClientSettingsService.instance;
      service.applyForTest(
        settings: const AppClientSettings(
          platform: 'ANDROID',
          minVersion: '2.0.0',
          latestVersion: '2.1.0',
          forceUpdate: true,
          maintenanceMode: false,
          updateUrl:
              'https://play.google.com/store/apps/details?id=com.example',
        ),
        currentVersion: '1.0.0',
      );
      expect(service.gate, AppSettingsGate.forceUpdate);
      expect(service.settings.validUpdateUri, isNotNull);
      expect(
        service.settings.validUpdateUri!.toString(),
        contains('play.google.com'),
      );
    });

    test('force update without URL allows session Continue (no dead-end)', () {
      final service = AppClientSettingsService.instance;
      service.applyForTest(
        settings: const AppClientSettings(
          platform: 'IOS',
          minVersion: '2.0.0',
          latestVersion: '2.1.0',
          forceUpdate: true,
          maintenanceMode: false,
          supportUrl: 'https://support.example/help',
        ),
        currentVersion: '1.0.0',
      );
      expect(service.gate, AppSettingsGate.forceUpdate);
      expect(service.settings.validUpdateUri, isNull);
      // supportUrl must NOT be treated as update destination
      expect(service.settings.supportUrl, isNotNull);

      service.continueWithoutUpdateDestination();
      expect(service.gate, AppSettingsGate.none);
      expect(service.forceUpdateContinued, isTrue);
    });

    test('invalid updateUrl does not unlock Update CTA path', () {
      final service = AppClientSettingsService.instance;
      service.applyForTest(
        settings: const AppClientSettings(
          platform: 'WEB',
          minVersion: '9.0.0',
          latestVersion: '9.1.0',
          forceUpdate: true,
          maintenanceMode: false,
          updateUrl: 'ftp://bad.example/app',
        ),
        currentVersion: '1.0.0',
      );
      expect(service.gate, AppSettingsGate.forceUpdate);
      expect(service.settings.validUpdateUri, isNull);
      service.continueWithoutUpdateDestination();
      expect(service.gate, AppSettingsGate.none);
    });

    test('fromJson maps updateUrl and ignores support as update', () {
      final parsed = AppClientSettings.fromJson({
        'platform': 'ANDROID',
        'minVersion': '1.0.0',
        'latestVersion': '1.2.0',
        'forceUpdate': true,
        'maintenanceMode': false,
        'supportUrl': 'https://support.example',
        'updateUrl': 'https://play.example/app',
      });
      expect(parsed.updateUrl, 'https://play.example/app');
      expect(parsed.validUpdateUri!.host, 'play.example');
      expect(parsed.supportUrl, isNot(equals(parsed.updateUrl)));
    });
  });
}
