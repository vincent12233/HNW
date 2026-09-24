import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/app_config.dart';

void main() {
  test(
    'release API configuration accepts public HTTPS and same-origin paths',
    () {
      expect(
        AppConfig.isSafeReleaseApiBaseUrl('https://api.example.com'),
        isTrue,
      );
      expect(AppConfig.isSafeReleaseApiBaseUrl('/api'), isTrue);
      expect(AppConfig.isSafeReleaseApiBaseUrl('/'), isFalse);
      expect(AppConfig.isSafeReleaseApiBaseUrl('/api?x=1'), isFalse);
    },
  );

  test('release API configuration rejects cleartext and local targets', () {
    for (final value in [
      'http://api.example.com',
      'https://localhost:3000',
      'https://127.0.0.1',
      'https://10.0.0.2',
      'https://172.20.0.2',
      'https://192.168.1.2',
      'https://169.254.1.2',
      'https://100.64.0.1',
      'https://198.18.0.1',
      'https://[fc00::1]',
      'https://[fe80::1]',
      'https://[::ffff:127.0.0.1]',
      'https://[::ffff:7f00:1]',
      'https://[0:0:0:0:0:ffff:7f00:1]',
      'https://127.0.0.1.',
      'https://169.254.169.254.',
      'https://localhost.',
      'https://api.local',
      'https://api.internal',
      '//api.example.com',
      'https://user:pass@api.example.com',
      'not a url',
    ]) {
      expect(AppConfig.isSafeReleaseApiBaseUrl(value), isFalse, reason: value);
    }
  });

  test('Android release manifest blocks backups and cleartext traffic', () {
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(mainManifest, contains('android:allowBackup="false"'));
    expect(mainManifest, contains('android:usesCleartextTraffic="false"'));
    expect(
      mainManifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(
      mainManifest,
      contains('android:fullBackupContent="@xml/backup_rules"'),
    );

    expect(
      File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync(),
      contains('<device-transfer>'),
    );

    for (final variant in ['debug', 'profile']) {
      final developmentManifest = File(
        'android/app/src/$variant/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        developmentManifest,
        contains('android:usesCleartextTraffic="true"'),
        reason: variant,
      );
    }
  });
}
