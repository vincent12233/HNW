import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web manifest is customer branded and installable', () {
    final manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;

    expect(manifest['name'], 'HNW');
    expect(manifest['short_name'], 'HNW');
    expect(manifest['display'], 'standalone');
    expect(manifest['start_url'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['description'], isNot(contains('Flutter')));
    expect(manifest['description'], isNot(contains('project')));
    expect(manifest['theme_color'], '#1E3A8A');
  });

  test('index metadata contains no template or implementation details', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('<title>HNW</title>'));
    expect(html, contains('name="theme-color"'));
    expect(html, isNot(contains('A new Flutter project')));
    expect(html, isNot(contains('india_trading_app')));
  });
}
