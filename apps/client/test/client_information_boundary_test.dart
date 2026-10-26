import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/api_failure.dart';
import 'package:india_trading_app/services/error_telemetry.dart';
import 'package:india_trading_app/utils/client_error_message.dart';

void main() {
  group('customer-safe errors', () {
    test('known business codes become actionable customer copy', () {
      const failure = ApiFailure(
        message: 'PrismaClientKnownRequestError: column available_cash failed',
        code: 'INSUFFICIENT_AVAILABLE_BALANCE',
        requestId: 'req-safe-1',
        statusCode: 409,
      );

      final safe = clientSafeError(failure);

      expect(safe.message, 'Part of your balance is currently reserved.');
      expect(safe.requestId, 'req-safe-1');
      expect(safe.displayMessage, contains('Reference: req-safe-1'));
      expect(safe.displayMessage, isNot(contains('Prisma')));
      expect(safe.displayMessage, isNot(contains('available_cash')));
    });

    test('unknown server errors never expose infrastructure details', () {
      const failure = ApiFailure(
        message:
            'SQLSTATE 23505 at /srv/api/src/orders.ts redis://cache.internal',
        code: 'UNRECOGNIZED_PROVIDER_FAILURE',
        requestId: 'req-incident-42',
        statusCode: 500,
      );

      final safe = clientSafeError(
        failure,
        fallback: 'Order could not be sent',
      );

      expect(safe.message, 'Order could not be sent');
      expect(
        safe.displayMessage,
        'Order could not be sent\nReference: req-incident-42',
      );
      expect(safe.displayMessage, isNot(contains('SQLSTATE')));
      expect(safe.displayMessage, isNot(contains('/srv/')));
      expect(safe.displayMessage, isNot(contains('redis://')));
    });

    test('request references reject hostile or internal values', () {
      const failure = ApiFailure(
        message: 'Unexpected failure',
        requestId: '../../prod?token=secret',
        statusCode: 500,
      );

      expect(clientSafeError(failure).requestId, isNull);
      expect(clientErrorMessage(failure), 'Request failed');
    });
  });

  test('telemetry removes financial identity network and body details', () {
    final report = ErrorTelemetry.instance.buildReport(
      StateError(
        'PAN ABCDE1234F aadhaar 1234 5678 9012 account 123456789012 '
        'IFSC HDFC0001234 https://api.internal/v1/orders body={"pin":"1234"}',
      ),
      StackTrace.fromString(
        'at C:\\Users\\operator\\repo\\lib.dart:8:2\n'
        'at /srv/hnw/api/orders.ts:42:7',
      ),
      operation:
          'POST https://prod.internal/v1/orders?token=private body=secret',
    );

    final serialized = report.toString();
    for (final secret in <String>[
      'ABCDE1234F',
      '1234 5678 9012',
      '123456789012',
      'HDFC0001234',
      'api.internal',
      'prod.internal',
      'operator',
      '/srv/hnw',
      'body=secret',
      '"pin":"1234"',
    ]) {
      expect(serialized, isNot(contains(secret)), reason: secret);
    }
  });
}
