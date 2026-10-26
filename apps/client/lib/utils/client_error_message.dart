import '../services/auth_service.dart';
import '../services/api_failure.dart';
import '../l10n/app_language.dart';

class ClientSafeError {
  const ClientSafeError(this.message, {this.requestId});

  final String message;
  final String? requestId;

  String get displayMessage =>
      requestId == null ? message : '$message\n${tr('Reference')}: $requestId';
}

const _safeBusinessMessages = <String, String>{
  'INSUFFICIENT_AVAILABLE_BALANCE':
      'Part of your balance is currently reserved.',
  'INSUFFICIENT_BALANCE': 'Your available balance is insufficient.',
  'MARKET_CLOSED': 'The market is currently closed.',
  'KYC_REQUIRED': 'Complete identity verification to continue.',
  'KYC_PENDING': 'Your identity verification is under review.',
  'UNAUTHORIZED': 'Your session has expired. Please sign in again.',
  'FORBIDDEN': 'This action is not available for your account.',
  'RATE_LIMITED': 'Too many attempts. Wait a moment and try again.',
  'DUPLICATE_REQUEST': 'This request has already been received.',
  'ORDER_NOT_FOUND': 'This order is no longer available.',
  'INSTRUMENT_NOT_FOUND': 'This instrument is no longer available.',
};

ClientSafeError clientSafeError(
  Object error, {
  String fallback = 'Request failed',
}) {
  if (error is ApiFailure) {
    final message = _safeBusinessMessages[error.code];
    return ClientSafeError(
      tr(message ?? fallback),
      requestId: _safeRequestId(error.requestId),
    );
  }

  if (error is AuthException) {
    final mapped = error.code == null
        ? null
        : _safeBusinessMessages[error.code];
    final message = mapped ?? _safeCustomerMessage(error.message, fallback);
    return ClientSafeError(
      tr(message),
      requestId: _safeRequestId(error.requestId),
    );
  }

  final raw = error.toString();
  if (_isNetworkError(raw)) {
    return ClientSafeError(
      tr('Connection lost. Check your network and try again.'),
    );
  }
  if (raw.contains('FormatException') || raw.contains('Unexpected')) {
    return ClientSafeError(
      tr('The service returned an invalid response. Try again shortly.'),
    );
  }
  return ClientSafeError(tr(_safeCustomerMessage(raw, fallback)));
}

String clientErrorMessage(Object error, {String fallback = 'Request failed'}) {
  return clientSafeError(error, fallback: fallback).displayMessage;
}

String? _safeRequestId(String? value) {
  final candidate = value?.trim();
  if (candidate == null || candidate.isEmpty) return null;
  return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,79}$').hasMatch(candidate)
      ? candidate
      : null;
}

bool _isNetworkError(String raw) =>
    raw.contains('ClientException') ||
    raw.contains('Failed to fetch') ||
    raw.contains('SocketException') ||
    raw.contains('Connection refused') ||
    raw.contains('XMLHttpRequest') ||
    raw.contains('NetworkError');

String _safeCustomerMessage(String raw, String fallback) {
  if (raw.isEmpty || RegExp(r'[\u3400-\u9fff]').hasMatch(raw)) return fallback;
  if (RegExp(
    r'https?://|\b(?:Exception|Error|SQLSTATE|SELECT|INSERT|UPDATE|DELETE|Prisma|PostgreSQL|Redis|MongoDB)\b|uri=|[A-Za-z]:\\|/(?:srv|var|home|Users)/|\b(?:SUPER_ADMIN|DATABASE_URL|API_URL)\b',
    caseSensitive: false,
  ).hasMatch(raw)) {
    return fallback;
  }
  return raw.length <= 240 ? raw : fallback;
}
