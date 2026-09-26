import 'package:flutter_test/flutter_test.dart';
import 'package:india_trading_app/models/async_data_state.dart';

void main() {
  test('distinguishes empty successful data from an error', () {
    final empty = AsyncDataState<List<int>>.success(const []);
    final error = const AsyncDataState<List<int>>.error('failed');

    expect(empty.status, AsyncDataStatus.empty);
    expect(error.status, AsyncDataStatus.error);
  });

  test('marks cached offline data and keeps its timestamp', () {
    final timestamp = DateTime.utc(2026, 9, 26);
    final state = AsyncDataState<List<int>>.offline(const [
      1,
    ], updatedAt: timestamp);

    expect(state.status, AsyncDataStatus.offline);
    expect(state.requiresNotice, isTrue);
    expect(state.updatedAt, timestamp);
    expect(state.message, isNull);
  });
}
