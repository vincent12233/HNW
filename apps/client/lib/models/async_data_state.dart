enum AsyncDataStatus { initial, loading, success, empty, stale, offline, error }

class AsyncDataState<T> {
  const AsyncDataState._(
    this.status, {
    this.data,
    this.message,
    this.updatedAt,
    this.requestGeneration = 0,
  });

  const AsyncDataState.initial() : this._(AsyncDataStatus.initial);
  const AsyncDataState.loading({
    T? data,
    String? message,
    DateTime? updatedAt,
    int requestGeneration = 0,
  }) : this._(
         AsyncDataStatus.loading,
         data: data,
         message: message,
         updatedAt: updatedAt,
         requestGeneration: requestGeneration,
       );
  const AsyncDataState.error(String message, {int requestGeneration = 0})
    : this._(
        AsyncDataStatus.error,
        message: message,
        requestGeneration: requestGeneration,
      );

  AsyncDataState.success(
    T value, {
    DateTime? updatedAt,
    int requestGeneration = 0,
  }) : this._(
         _isEmpty(value) ? AsyncDataStatus.empty : AsyncDataStatus.success,
         data: value,
         updatedAt: updatedAt ?? DateTime.now(),
         requestGeneration: requestGeneration,
       );

  AsyncDataState.stale(
    T value, {
    required DateTime updatedAt,
    String? message,
    int requestGeneration = 0,
  }) : this._(
         AsyncDataStatus.stale,
         data: value,
         updatedAt: updatedAt,
         message: message,
         requestGeneration: requestGeneration,
       );

  AsyncDataState.offline(
    T value, {
    required DateTime updatedAt,
    String? message,
    int requestGeneration = 0,
  }) : this._(
         AsyncDataStatus.offline,
         data: value,
         updatedAt: updatedAt,
         message: message,
         requestGeneration: requestGeneration,
       );

  final AsyncDataStatus status;
  final T? data;
  final String? message;
  final DateTime? updatedAt;
  final int requestGeneration;

  bool get hasData => data != null;
  bool get isLoading => status == AsyncDataStatus.loading;
  bool get isFresh => status == AsyncDataStatus.success;
  bool get requiresNotice =>
      status == AsyncDataStatus.stale || status == AsyncDataStatus.offline;
  bool acceptsResponse(int generation) => generation == requestGeneration;

  static bool _isEmpty(Object? value) => switch (value) {
    String value => value.isEmpty,
    Iterable value => value.isEmpty,
    Map value => value.isEmpty,
    _ => false,
  };
}
