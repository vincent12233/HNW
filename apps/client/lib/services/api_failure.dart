class ApiFailure implements Exception {
  const ApiFailure({
    required this.message,
    this.code = 'REQUEST_FAILED',
    this.requestId,
    this.statusCode,
  });

  factory ApiFailure.fromResponse(
    int statusCode,
    dynamic decoded, {
    String fallback = 'Unable to complete request',
  }) {
    final body = decoded is Map ? decoded : const <String, dynamic>{};
    return ApiFailure(
      message: body['message']?.toString() ?? fallback,
      code: body['code']?.toString() ?? _defaultCode(statusCode),
      requestId: body['requestId']?.toString(),
      statusCode: statusCode,
    );
  }

  final String message;
  final String code;
  final String? requestId;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || code == 'UNAUTHORIZED';
  bool get isRetryable =>
      statusCode == null ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  static String _defaultCode(int statusCode) => switch (statusCode) {
    401 => 'UNAUTHORIZED',
    403 => 'FORBIDDEN',
    404 => 'NOT_FOUND',
    409 => 'CONFLICT',
    >= 500 => 'INTERNAL_ERROR',
    _ => 'REQUEST_FAILED',
  };

  @override
  String toString() => message;
}
