import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/services/pending_ipo_operation.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('concurrent attempts and ambiguous retries reuse persisted identity', () async {
    final keys = await Future.wait([
      PendingIpoOperation.begin('account', 'ipo'),
      PendingIpoOperation.begin('account', 'ipo'),
    ]);
    expect(keys[0], keys[1]);
    expect(await PendingIpoOperation.begin('account', 'ipo'), keys[0]);
    expect(await PendingIpoOperation.begin('other-account', 'ipo'), isNot(keys[0]));
    expect(await PendingIpoOperation.begin('account', 'other-ipo'), isNot(keys[0]));
    await PendingIpoOperation.complete('account', 'ipo');
    expect(await PendingIpoOperation.begin('account', 'ipo'), isNot(keys[0]));
  });
}
