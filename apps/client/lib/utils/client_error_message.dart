import '../services/auth_service.dart';

String clientErrorMessage(Object error, {String fallback = 'Request failed'}) {
  if (error is AuthException) {
    return error.message;
  }

  final raw = error.toString();
  if (RegExp(r'[\u3400-\u9fff]').hasMatch(raw)) {
    return fallback;
  }

  if (raw.contains('ClientException') ||
      raw.contains('Failed to fetch') ||
      raw.contains('SocketException') ||
      raw.contains('Connection refused') ||
      raw.contains('XMLHttpRequest') ||
      raw.contains('NetworkError')) {
    return 'Connection lost. Check your network and try again.';
  }

  if (raw.contains('FormatException') || raw.contains('Unexpected')) {
    return 'The service returned an invalid response. Try again shortly.';
  }

  if (RegExp(r'https?://|Exception|Error:|uri=').hasMatch(raw)) {
    return fallback;
  }

  return raw.isEmpty ? fallback : raw;
}
