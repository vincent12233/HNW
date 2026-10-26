import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer web container is non-root and release-only', () {
    final dockerfile = File(
      '../../docker/client-web.Dockerfile',
    ).readAsStringSync();
    final compose = File('../../compose.production.yaml').readAsStringSync();

    expect(dockerfile, contains('flutter build web --release'));
    expect(dockerfile, contains('USER 101'));
    expect(compose, contains('client-web:'));
    expect(compose, contains('read_only: true'));
    expect(compose, contains('no-new-privileges:true'));
    expect(compose, contains('cap_drop:'));
  });

  test('nginx separates SPA, immutable assets, and sensitive traffic', () {
    final nginx = File('../../docker/client-web.nginx.conf').readAsStringSync();
    final headers = File(
      '../../docker/client-web.security-headers.conf',
    ).readAsStringSync();

    expect(nginx, contains('try_files \$uri \$uri/ /index.html'));
    expect(nginx, contains('try_files \$uri =404'));
    expect(nginx, contains('location /api/'));
    expect(nginx, contains('location /ws/'));
    expect(nginx, contains('Cache-Control "no-store"'));
    expect(headers, contains("frame-ancestors 'none'"));
    expect(headers, contains('Strict-Transport-Security'));
    expect(headers, contains('Permissions-Policy'));
  });
}
