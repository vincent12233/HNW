import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import 'auth_service.dart';

class ClientAccountService {
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
    if (method == 'GET')
      response = await http.get(uri, headers: headers);
    else if (method == 'POST')
      response = await http.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      );
    else if (method == 'PATCH')
      response = await http.patch(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
    else
      response = await http.delete(uri, headers: headers);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['message']?.toString() : null;
      throw AuthException(message ?? 'Unable to complete request');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> profile() async => Map<String, dynamic>.from(
    await _request('GET', '/client/profile') as Map,
  );
  Future<Map<String, dynamic>> updateProfile(String name, String email) async =>
      Map<String, dynamic>.from(
        await _request(
              'PATCH',
              '/client/profile',
              body: {'fullName': name, 'email': email},
            )
            as Map,
      );
  Future<void> changePassword(String current, String next) async {
    await _request(
      'POST',
      '/client/security/password',
      body: {'currentPassword': current, 'newPassword': next},
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
