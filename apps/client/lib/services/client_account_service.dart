import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'auth_service.dart';

class ClientAccountService {
  Future<List<Map<String, dynamic>>> loans() async {
    final rows = await _request('GET', '/loans/mine');
    if (rows is! List) {
      throw const AuthException('Unable to load loan applications');
    }
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> applyForLoan() async {
    final result = await _request(
      'POST',
      '/loans/apply',
      body: <String, dynamic>{},
    );
    if (result is! Map ||
        result['id'] is! String ||
        (result['id'] as String).trim().isEmpty ||
        result['status'] != 'PENDING') {
      throw const AuthException(
        'Unable to confirm application. Refresh to check its status.',
      );
    }
  }

  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final session = await _auth.restoreSession();
    if (session == null) throw AuthException('Please sign in again');
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<dynamic> _request(String method, String path, {Object? body}) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$path');
    final headers = await _headers();
    late http.Response response;
    try {
      if (method == 'GET') {
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      } else if (method == 'POST') {
        response = await http
            .post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      } else if (method == 'PATCH') {
        response = await http
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 15));
      } else {
        response = await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      }
    } catch (_) {
      throw const AuthException(
        'Unable to connect. Please check your network and try again.',
      );
    }
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      final code = decoded is Map ? decoded['code']?.toString() : null;
      final requestId = decoded is Map
          ? decoded['requestId']?.toString()
          : null;
      throw AuthException(
        message ?? 'Unable to complete request',
        code: code,
        requestId: requestId,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> profile() async => Map<String, dynamic>.from(
    await _request('GET', '/client/profile') as Map,
  );
  Future<Map<String, dynamic>> twoFactorStatus() async =>
      Map<String, dynamic>.from(
        await _request('GET', '/client/security/two-factor') as Map,
      );
  Future<String> updateAvatar(String base64) async =>
      (await _request(
            'PATCH',
            '/client/profile/avatar',
            body: {'base64': base64},
          ))['avatarData']
          as String;
  Future<Map<String, dynamic>> twoFactorAction(
    String action, {
    String? password,
    String? code,
  }) async => Map<String, dynamic>.from(
    await _request(
          'POST',
          '/client/security/two-factor/$action',
          body: {'currentPassword': password, 'code': code},
        )
        as Map,
  );
  Future<Map<String, dynamic>> updateProfile(String name) async =>
      Map<String, dynamic>.from(
        await _request('PATCH', '/client/profile', body: {'fullName': name})
            as Map,
      );
  Future<void> changePassword(String current, String next) async {
    await _request(
      'POST',
      '/client/security/password',
      body: {'currentPassword': current, 'newPassword': next},
    );
  }

  Future<Map<String, dynamic>> assetHistory(
    String period,
  ) async => Map<String, dynamic>.from(
    await _request(
          'GET',
          '/client/assets/history?period=${Uri.encodeQueryComponent(period)}',
        )
        as Map,
  );

  Future<bool> hasWithdrawalPin() async =>
      (await _request(
        'GET',
        '/client/security/withdrawal-pin',
      ))['configured'] ==
      true;

  Future<Map<String, dynamic>> productPortfolio(
    String period,
  ) async => Map<String, dynamic>.from(
    await _request(
          'GET',
          '/client/portfolio/products?period=${Uri.encodeQueryComponent(period)}',
        )
        as Map,
  );

  Future<void> changeWithdrawalPin(
    String password,
    String currentPin,
    String newPin,
  ) async {
    await _request(
      'POST',
      '/client/security/withdrawal-pin',
      body: {
        'currentPassword': password,
        'currentPin': currentPin,
        'newPin': newPin,
      },
    );
  }

  Future<List<Map<String, dynamic>>> banks() async =>
      (await _request('GET', '/client/bank-accounts') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> addBank(Map<String, String> data) async {
    await _request('POST', '/client/bank-accounts', body: data);
  }

  Future<void> deleteBank(String id) async {
    await _request('DELETE', '/client/bank-accounts/$id');
  }

  Future<List<Map<String, dynamic>>> devices() async =>
      (await _request('GET', '/client/security/devices') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> revokeDevice(String id) async {
    await _request('DELETE', '/client/security/devices/$id');
  }

  Future<Map<String, dynamic>> preferences() async => Map<String, dynamic>.from(
    await _request('GET', '/client/preferences') as Map,
  );
  Future<void> updatePreferences(Map<String, dynamic> data) async {
    await _request('PATCH', '/client/preferences', body: data);
  }

  Future<List<Map<String, dynamic>>> notifications() async =>
      (await _request('GET', '/client/notifications') as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
  Future<void> readAllNotifications() async {
    await _request('POST', '/client/notifications/read-all');
  }

  Future<void> readNotification(String id) async {
    await _request('POST', '/client/notifications/$id/read');
  }

  Future<Map<String, dynamic>> reconciliation() async =>
      Map<String, dynamic>.from(
        await _request('GET', '/client/portfolio/reconciliation') as Map,
      );
  Future<Map<String, dynamic>> kycStatus() async {
    return Map<String, dynamic>.from(
      await _request('GET', '/kyc/status') as Map,
    );
  }
}
