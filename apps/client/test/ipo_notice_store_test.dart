import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:india_trading_app/services/ipo_notice_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new allotment is not acknowledged', () async {
    expect(await IpoNoticeStore().isConfirmed('new'), isFalse);
  });

  test('confirmation survives a new store instance', () async {
    await IpoNoticeStore().confirm('application-a');
    expect(await IpoNoticeStore().isConfirmed('application-a'), isTrue);
  });

  test('confirmation does not suppress a different application', () async {
    await IpoNoticeStore().confirm('application-a');
    expect(await IpoNoticeStore().isConfirmed('application-b'), isFalse);
  });
}
