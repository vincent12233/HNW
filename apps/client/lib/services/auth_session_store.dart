import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import 'secure_credential_store.dart';

/// Owns durable authentication state. Network orchestration stays in AuthService.
class AuthSessionStore {
  AuthSessionStore({SecureCredentialStore? credentials})
    : _credentials = credentials ?? SecureCredentialStore.instance;

  static const sessionKey = SecureCredentialStore.sessionKey;
  static const biometricSessionKey = SecureCredentialStore.biometricSessionKey;

  final SecureCredentialStore _credentials;

  Future<AuthSession?> read() async {
    final preferences = await SharedPreferences.getInstance();
    var encoded = await _credentials.readSession();
    final legacy = preferences.getString(sessionKey);
    if (encoded == null && legacy != null) {
      encoded = legacy;
      await _credentials.writeSession(legacy);
    }
    if (legacy != null) await preferences.remove(sessionKey);
    if (encoded == null) return null;
    try {
      final session = AuthSession.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      return session.isValid ? session : null;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> write(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await _credentials.writeSession(jsonEncode(session.toJson()));
    await preferences.remove(sessionKey);
    await preferences.setString('account_name', session.fullName);
    await preferences.setString('account_phone', session.phone);
  }

  Future<String?> readBiometricToken() async {
    final preferences = await SharedPreferences.getInstance();
    var token = await _credentials.readBiometricToken();
    token ??= preferences.getString(biometricSessionKey);
    if (token != null && preferences.containsKey(biometricSessionKey)) {
      await _credentials.writeBiometricToken(token);
      await preferences.remove(biometricSessionKey);
    }
    return token;
  }

  Future<void> writeBiometricToken(String token) =>
      _credentials.writeBiometricToken(token);

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await _credentials.deleteSession();
    await _credentials.deleteBiometricToken();
    await preferences.remove(sessionKey);
    await preferences.remove(biometricSessionKey);
  }
}
