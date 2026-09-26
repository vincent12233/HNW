enum AsyncDataStatus { initial, loading, success, empty, stale, offline, error }

class AsyncDataState<T> {
  const AsyncDataState._(
    this.status, {
    this.data,
    this.message,
    this.updatedAt,
  });

  const AsyncDataState.initial() : this._(AsyncDataStatus.initial);
  const AsyncDataState.loading() : this._(AsyncDataStatus.loading);
  const AsyncDataState.error(String message)
    : this._(AsyncDataStatus.error, message: message);

  AsyncDataState.success(T value, {DateTime? updatedAt})
    : this._(
        _isEmpty(value) ? AsyncDataStatus.empty : AsyncDataStatus.success,
        data: value,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  AsyncDataState.stale(T value, {required DateTime updatedAt, String? message})
    : this._(
        AsyncDataStatus.stale,
        data: value,
        updatedAt: updatedAt,
        message: message,
      );

  AsyncDataState.offline(
    T value, {
    required DateTime updatedAt,
    String? message,
  }) : this._(
         AsyncDataStatus.offline,
         data: value,
         updatedAt: updatedAt,
         message: message,
       );

  final AsyncDataStatus status;
  final T? data;
  final String? message;
  final DateTime? updatedAt;

  bool get hasData => data != null;
  bool get isLoading => status == AsyncDataStatus.loading;
  bool get isFresh => status == AsyncDataStatus.success;
  bool get requiresNotice =>
      status == AsyncDataStatus.stale || status == AsyncDataStatus.offline;

  static bool _isEmpty(Object? value) => switch (value) {
    String value => value.isEmpty,
    Iterable value => value.isEmpty,
    Map value => value.isEmpty,
    _ => false,
  };
}
