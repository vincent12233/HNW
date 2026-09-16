import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/services/auth_service.dart';
import 'package:india_trading_app/utils/client_error_message.dart';

void main() {
  test('backend Chinese errors use an English message', () {
    const error = AuthException('\u64cd\u4f5c\u5931\u8d25');
    expect(error.message, 'Unable to complete this request. Please try again.');
    expect(clientErrorMessage(error), error.message);
    expect(
      clientErrorMessage(Exception('\u64cd\u4f5c\u5931\u8d25')),
      'Request failed',
    );
  });
  test('English errors retain their useful detail', () {
    const error = AuthException('Insufficient available balance');
    expect(clientErrorMessage(error), 'Insufficient available balance');
  });
}
