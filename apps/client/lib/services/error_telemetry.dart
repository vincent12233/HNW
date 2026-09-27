import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';

typedef ErrorTelemetrySink = void Function(Map<String, Object?> report);

class ErrorTelemetry {
  ErrorTelemetry._();

  static final ErrorTelemetry instance = ErrorTelemetry._();

  ErrorTelemetrySink? sink;

  void install() {
    sink ??= _sendToApi;
    FlutterError.onError = (details) {
      record(
        details.exception,
        details.stack,
        operation: details.library ?? 'flutter_framework',
      );
      if (kDebugMode) FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      final report = record(error, stack, operation: 'platform_dispatcher');
      if (kDebugMode) {
        debugPrint(
          'Unhandled asynchronous error captured: ${report['fingerprint']}',
        );
      }
      return true;
    };
  }

  Map<String, Object?> record(
    Object error,
    StackTrace? stack, {
    required String operation,
  }) {
    final report = buildReport(error, stack, operation: operation);
    sink?.call(report);
    return report;
  }

  Map<String, Object?> buildReport(
    Object error,
    StackTrace? stack, {
    required String operation,
  }) {
    final safeOperation = sanitize(operation);
    final safeMessage = sanitize(error.toString());
    final safeStack = stack == null ? null : sanitize(stack.toString());
    final fingerprint = sha256
        .convert(
          utf8.encode(
            '${error.runtimeType}\n$safeOperation\n$safeMessage\n${safeStack ?? ''}',
          ),
        )
        .toString()
        .substring(0, 16);
    return <String, Object?>{
      'event': 'client_error',
      'operation': safeOperation,
      'error': error.runtimeType.toString(),
      'fingerprint': fingerprint,
      'message': safeMessage,
      'stack': ?safeStack,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
  }

  void _sendToApi(Map<String, Object?> report) {
    unawaited(
      http
          .post(
            Uri.parse('${AppConfig.apiBaseUrl}/observability/client-errors'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode(report),
          )
          .timeout(const Duration(seconds: 3))
          .catchError((_) => http.Response('', 503)),
    );
  }

  String sanitize(String value) {
    var result = value;
    result = result.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
      'Bearer [REDACTED]',
    );
    result = result.replaceAll(
      RegExp(r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b'),
      '[JWT]',
    );
    result = result.replaceAll(
      RegExp(
        r'([?&](?:access_token|id_token|refresh_token|token|password|secret|code)=)[^&#\s]+',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    result = result.replaceAll(
      RegExp(
        r'((?:access_token|id_token|refresh_token|token|password|secret|authorization)\s*[:=]\s*)[^\s,;]+',
        caseSensitive: false,
      ),
      r'$1[REDACTED]',
    );
    result = result.replaceAll(
      RegExp(
        r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
        caseSensitive: false,
      ),
      '[EMAIL]',
    );
    result = result.replaceAll(RegExp(r'(?:\+?\d[\s-]?){10,15}'), '[PHONE]');
    result = result.replaceAll(
      RegExp(r'[A-Za-z]:\\Users\\[^\\\s]+', caseSensitive: false),
      '[USER_HOME]',
    );
    result = result.replaceAll(RegExp(r'/Users/[^/\s]+'), '[USER_HOME]');
    result = result.replaceAll(RegExp(r'/home/[^/\s]+'), '[USER_HOME]');
    result = result.replaceAll(
      RegExp(r'\b[A-Za-z0-9+/]{160,}={0,2}\b'),
      '[ENCODED_DATA]',
    );
    return result.length <= 4000 ? result : result.substring(0, 4000);
  }
}
