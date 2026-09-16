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
}
