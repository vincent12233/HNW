import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'auth_service.dart';
import 'secure_credential_store.dart';

/// Owns recovery transport and the persisted recovery credential.
class PasswordRecoveryService {
  final credentials = SecureCredentialStore.instance;
  String? token;
  Future<void> restore() async {
    token = await credentials.readRecoveryToken();
  }

  Future<void> save(String value) async {
    await credentials.writeRecoveryToken(value);
    token = value;
  }

  Future<void> clear() async {
    await credentials.deleteRecoveryToken();
    token = null;
  }

  Future<dynamic> request(String path, {Map<String, dynamic>? body}) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-recovery-token': ?token,
    };
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/recovery/$path');
    final response =
        await (body == null
                ? http.get(uri, headers: headers)
                : http.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      await credentials.deleteRecoveryToken();
      token = null;
      throw const AuthException('Please reconnect to customer support');
    }
    final data = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        data is Map
            ? data['message']?.toString() ?? 'Request failed'
            : 'Request failed',
      );
    }
    return data;
  }
}
