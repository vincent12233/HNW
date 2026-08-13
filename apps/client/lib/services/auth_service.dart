import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';
import '../models/auth_session.dart';
import '../models/withdrawal_request.dart';
import 'local_data_cache.dart';
import 'session_expiry_service.dart';

class AuthService {
  static const String _sessionKey = 'auth_session';
  static const String _biometricSessionKey = 'biometric_auth_session';
  final SessionExpiryService _sessionExpiry = SessionExpiryService();

  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/login');

    final http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': _normalizeIndianPhone(phone),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const AuthException(
        'Unable to connect. Please check your network and try again.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthException(message ?? 'Login failed');
    }

    if (decoded is! Map<String, dynamic>) {
      throw AuthException('Invalid login response');
    }

    final session = AuthSession.fromLoginJson(decoded);

    if (!session.isValid) {
      throw AuthException('Login response is missing session data');
    }

    await saveSession(session);

    return session;
  }

  Future<void> requestPasswordReset(String phone) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/password-reset/request'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': _normalizeIndianPhone(phone)}),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(decoded, 'Unable to send reset code'),
      );
    }
  }

  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/password-reset/confirm'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': _normalizeIndianPhone(phone),
            'code': code,
            'newPassword': newPassword,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(decoded, 'Unable to reset password'),
      );
    }
  }

  Future<AuthSession> googleLogin(String idToken) async {
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw AuthException(_englishApiMessage(decoded, 'Google sign in failed'));
    }
    final session = AuthSession.fromLoginJson(decoded);
    await saveSession(session);
    return session;
  }

  Future<void> linkGoogle(String idToken) async {
    final session = await restoreSession();
    if (session == null) throw AuthException('Please sign in again');
    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/auth/google/link'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 12));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw AuthException(
        _englishApiMessage(decoded, 'Unable to link Google account'),
      );
  }

  Future<void> register({
    required String phone,
    required String password,
    required String inviteCode,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/register');

    final http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': _normalizeIndianPhone(phone),
              'password': password,
              'inviteCode': inviteCode.trim().toUpperCase(),
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const AuthException(
        'Unable to connect. Please check your network and try again.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthException(message ?? 'Registration failed');
    }
  }

  Future<String> submitKyc({
    required String phone,
    required String documentType,
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      throw AuthException('Unable to read selected KYC file');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/kyc/submit');

    final http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': _normalizeIndianPhone(phone),
              'documentType': documentType,
              'fileName': file.name,
              'mimeType': _mimeTypeForFile(file.name),
              'contentBase64': base64Encode(bytes),
            }),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const AuthException(
        'Unable to connect. Please check your network and try again.',
      );
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthException(message ?? 'KYC upload failed');
    }

    if (decoded is Map) {
      return decoded['recognizedType']?.toString() ?? documentType;
    }

    return documentType;
  }

  Future<List<WithdrawalRequest>> fetchWithdrawals() async {
    final session = await restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      return <WithdrawalRequest>[];
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/withdrawal/me'),
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));

      if (_sessionExpiry.isUnauthorized(response.statusCode)) {
        await _sessionExpiry.expire();
        return <WithdrawalRequest>[];
      }

      final decoded = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          _englishApiMessage(decoded, 'Unable to load withdrawals'),
        );
      }

      if (decoded is! List) {
        return _cachedWithdrawals();
      }

      await LocalDataCache.saveJson(LocalDataCache.withdrawals, decoded);

      return _withdrawalsFromRows(decoded);
    } catch (_) {
      return _cachedWithdrawals();
    }
  }

  Future<WithdrawalRequest> submitWithdrawal({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    String? note,
  }) async {
    final session = await restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      throw AuthException('Please sign in again');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/withdrawal/request'),
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'amount': amount,
            'bankName': bankName,
            'accountNumber': accountNumber,
            'ifscCode': ifscCode,
            'note': note,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw AuthException('Please sign in again');
    }

    final decoded = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(decoded, 'Withdrawal request failed'),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw AuthException('Invalid withdrawal response');
    }

    return WithdrawalRequest.fromJson(decoded);
  }

  Future<void> contactSupport(String content) async {
    final conversationId = await openSupportConversation();
    await sendSupportMessage(conversationId, content);
  }

  Future<String> openSupportConversation() async {
    final session = await restoreSession();

    if (session == null || session.accessToken.isEmpty) {
      throw AuthException('Please sign in again');
    }

    final headers = {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };

    final conversationResponse = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/support/conversations'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(conversationResponse.statusCode)) {
      await _sessionExpiry.expire();
      throw AuthException('Please sign in again');
    }

    final conversationDecoded = jsonDecode(conversationResponse.body);

    if (conversationResponse.statusCode < 200 ||
        conversationResponse.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(conversationDecoded, 'Unable to contact support'),
      );
    }

    if (conversationDecoded is! Map<String, dynamic>) {
      throw AuthException('Invalid support response');
    }

    final conversationId = conversationDecoded['id']?.toString() ?? '';

    if (conversationId.isEmpty) {
      throw AuthException('Support conversation was not created');
    }

    return conversationId;
  }

  Future<List<Map<String, dynamic>>> fetchSupportMessages(
    String conversationId,
  ) async {
    final session = await restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw AuthException('Please sign in again');
    }
    final response = await http
        .get(
          Uri.parse(
            '${AppConfig.apiBaseUrl}/support/conversations/$conversationId/messages',
          ),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 10));
    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw AuthException('Please sign in again');
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(decoded, 'Unable to load messages'),
      );
    }
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
  }

  Future<void> sendSupportMessage(
    String conversationId,
    String content, {
    String? attachmentName,
    String? attachmentType,
    String? attachmentBase64,
  }) async {
    final session = await restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw AuthException('Please sign in again');
    }
    final headers = {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };

    final messageResponse = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/support/messages'),
          headers: headers,
          body: jsonEncode({
            'conversationId': conversationId,
            'content': content.trim(),
            if (attachmentName != null) 'attachmentName': attachmentName,
            if (attachmentType != null) 'attachmentType': attachmentType,
            if (attachmentBase64 != null) 'attachmentBase64': attachmentBase64,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(messageResponse.statusCode)) {
      await _sessionExpiry.expire();
      throw AuthException('Please sign in again');
    }

    final messageDecoded = jsonDecode(messageResponse.body);

    if (messageResponse.statusCode < 200 || messageResponse.statusCode >= 300) {
      throw AuthException(
        _englishApiMessage(messageDecoded, 'Unable to send message'),
      );
    }
  }

  Future<void> markSupportConversationRead(String conversationId) async {
    final session = await restoreSession();
    if (session == null) return;
    await http.post(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/support/conversations/$conversationId/read',
      ),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
  }

  Future<bool> supportOnline() async {
    final session = await restoreSession();
    if (session == null) return false;
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/support/status'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final decoded = jsonDecode(response.body);
    return decoded is Map && decoded['online'] == true;
  }

  Future<AuthSession?> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_sessionKey);

    if (saved == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(saved) as Map<String, dynamic>;
      final session = AuthSession.fromJson(decoded);

      return session.isValid ? session : null;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
    await preferences.setString('account_name', session.fullName);
    await preferences.setString('account_phone', session.phone);
  }

  Future<void> enableBiometricQuickLogin() async {
    final session = await restoreSession();
    if (session == null) throw AuthException('Please sign in again');
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/biometric/token'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      throw AuthException(
        _englishApiMessage(decoded, 'Unable to enable biometric login'),
      );
    }
    final token = decoded['biometricToken']?.toString() ?? '';
    if (token.isEmpty) throw AuthException('Invalid biometric login response');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_biometricSessionKey, token);
  }

  Future<void> disableBiometricQuickLogin() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_biometricSessionKey);
  }

  Future<String?> restoreBiometricToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_biometricSessionKey);
  }

  Future<AuthSession> biometricLogin(String biometricToken) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/biometric/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'biometricToken': biometricToken}),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic>) {
      throw AuthException(
        _englishApiMessage(decoded, 'Biometric quick login failed'),
      );
    }
    final session = AuthSession.fromLoginJson(decoded);
    await saveSession(session);
    return session;
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}

Future<List<WithdrawalRequest>> _cachedWithdrawals() async {
  final cached = await LocalDataCache.readJson(LocalDataCache.withdrawals);

  if (cached is List) {
    return _withdrawalsFromRows(cached);
  }

  return <WithdrawalRequest>[];
}

List<WithdrawalRequest> _withdrawalsFromRows(List<dynamic> rows) {
  return rows
      .map(
        (item) =>
            WithdrawalRequest.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

String _normalizeIndianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');

  if (digits.length == 12 && digits.startsWith('91')) {
    return digits.substring(2);
  }

  return digits;
}

String _mimeTypeForFile(String fileName) {
  final lowerName = fileName.toLowerCase();

  if (lowerName.endsWith('.pdf')) return 'application/pdf';
  if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lowerName.endsWith('.png')) return 'image/png';
  if (lowerName.endsWith('.webp')) return 'image/webp';

  return 'application/octet-stream';
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _englishApiMessage(dynamic decoded, String fallback) {
  final message = decoded is Map ? decoded['message']?.toString() : null;

  switch (message) {
    case 'Amount must be greater than zero':
      return 'Amount must be greater than zero';
    case 'Provide either UPI ID or complete bank details':
      return 'Please provide complete withdrawal details';
    case 'Insufficient cash balance':
      return 'Insufficient cash balance';
    case 'Account not found':
    case '未找到账户':
      return 'Trading account not found';
    case '消息内容不能为空':
      return 'Message cannot be empty';
    case '未找到客服会话':
      return 'Support conversation not found';
    case '无权访问该客服会话':
      return 'You cannot access this support conversation';
    default:
      return message == null || RegExp(r'[\u4e00-\u9fff]').hasMatch(message)
          ? fallback
          : message;
  }
}
