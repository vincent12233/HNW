import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The single boundary for sensitive client credentials.
///
/// Widgets and feature services must not instantiate [FlutterSecureStorage]
/// directly. Non-sensitive preferences (theme, locale, display name) belong in
/// SharedPreferences; access tokens, biometric tokens and recovery tokens do
/// not.
class SecureCredentialStore {
  SecureCredentialStore._();

  static final SecureCredentialStore instance = SecureCredentialStore._();

  static const String sessionKey = 'auth_session';
  static const String biometricSessionKey = 'biometric_auth_session';
  static const String recoveryTokenKey = 'recovery_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      migrateOnAlgorithmChange: true,
      migrateWithBackup: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<String?> readSession() => _storage.read(key: sessionKey);
  Future<void> writeSession(String value) =>
      _storage.write(key: sessionKey, value: value);
  Future<void> deleteSession() => _storage.delete(key: sessionKey);

  Future<String?> readBiometricToken() =>
      _storage.read(key: biometricSessionKey);
  Future<void> writeBiometricToken(String value) =>
      _storage.write(key: biometricSessionKey, value: value);
  Future<void> deleteBiometricToken() =>
      _storage.delete(key: biometricSessionKey);

  Future<String?> readRecoveryToken() => _storage.read(key: recoveryTokenKey);
  Future<void> writeRecoveryToken(String value) =>
      _storage.write(key: recoveryTokenKey, value: value);
  Future<void> deleteRecoveryToken() => _storage.delete(key: recoveryTokenKey);

  Future<void> clearAuthenticationCredentials() async {
    await Future.wait([
      deleteSession(),
      deleteBiometricToken(),
      deleteRecoveryToken(),
    ]);
  }
}
