import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA worker bypasses sensitive and financial traffic', () {
    final worker = File('web/pwa_service_worker.js').readAsStringSync();

    for (final path in const [
      '/api',
      '/ws',
      '/auth',
      '/kyc',
      '/support',
      '/account',
      '/deposit',
      '/withdraw',
      '/order',
      '/trade',
    ]) {
      expect(worker, contains("'$path'"), reason: '$path must bypass cache');
    }
    expect(worker, contains("request.method !== 'GET'"));
    expect(worker, contains("cache: 'no-store'"));
    expect(worker, isNot(contains('sync.register')));
  });
}
