import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/error_telemetry.dart';

void main() {
  test('client error telemetry removes credentials and PII', () {
    final encoded = List.filled(200, 'A').join();
    final error = StateError(
      'Bearer secret-token person@example.com +91 98765 43210 $encoded',
    );
    final stack = StackTrace.fromString(
      'token=private-token at C:\\Users\\private-user\\app.dart:1',
    );
    final report = ErrorTelemetry.instance.buildReport(
      error,
      stack,
      operation: 'POST /login?id_token=private-jwt',
    );
    final serialized = report.toString();
    expect(serialized, isNot(contains('secret-token')));
    expect(serialized, isNot(contains('private-token')));
    expect(serialized, isNot(contains('private-jwt')));
    expect(serialized, isNot(contains('person@example.com')));
    expect(serialized, isNot(contains('98765')));
    expect(serialized, isNot(contains('private-user')));
    expect(serialized, isNot(contains(encoded)));
    expect(report['fingerprint'], hasLength(16));
  });

  test(
    'client error telemetry sends only the sanitized report to its sink',
    () {
      Map<String, Object?>? received;
      ErrorTelemetry.instance.sink = (report) => received = report;
      final report = ErrorTelemetry.instance.record(
        Exception('password=top-secret'),
        StackTrace.current,
        operation: 'authentication',
      );
      expect(received, same(report));
      expect(received.toString(), isNot(contains('top-secret')));
      ErrorTelemetry.instance.sink = null;
    },
  );
}
