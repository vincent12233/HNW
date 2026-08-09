import '../services/auth_service.dart';

String clientErrorMessage(Object error, {String fallback = 'Request failed'}) {
  if (error is AuthException) {
    return error.message;
  }

  final raw = error.toString();

  if (raw.contains('ClientException') ||
      raw.contains('Failed to fetch') ||
      raw.contains('SocketException') ||
      raw.contains('Connection refused') ||
      raw.contains('XMLHttpRequest') ||
      raw.contains('NetworkError')) {
    return 'Unable to connect. Please check your network and try again.';
  }

  if (raw.contains('FormatException') || raw.contains('Unexpected')) {
    return 'Unable to process the response. Please try again later.';
  }

  if (RegExp(r'https?://|Exception|Error:|uri=').hasMatch(raw)) {
    return fallback;
  }

  return raw.isEmpty ? fallback : raw;
}
