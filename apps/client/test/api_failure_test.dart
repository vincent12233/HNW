import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/api_failure.dart';

void main() {
  test('preserves stable API error metadata', () {
    final failure = ApiFailure.fromResponse(409, {
      'code': 'DUPLICATE_REQUEST',
      'message': 'Already submitted',
      'requestId': 'request-1',
    });

    expect(failure.code, 'DUPLICATE_REQUEST');
    expect(failure.message, 'Already submitted');
    expect(failure.requestId, 'request-1');
    expect(failure.isRetryable, isFalse);
  });

  test('classifies server and network failures as retryable', () {
    expect(ApiFailure.fromResponse(503, {}).isRetryable, isTrue);
    expect(
      const ApiFailure(message: 'Network unavailable').isRetryable,
      isTrue,
    );
  });
}
