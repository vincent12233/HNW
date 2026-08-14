import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_config.dart';
import '../models/institutional_opportunity.dart';
import 'auth_service.dart';

class OtcService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final session = await _auth.restoreSession();
    if (session == null) throw const OtcException('Please sign in again');
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  Future<List<InstitutionalStock>> offers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/otc/offers'),
      headers: await _headers(),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw OtcException(_message(decoded));
    return (decoded as List)
        .whereType<Map>()
        .map(
          (row) =>
              InstitutionalStock.fromOtcJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<List<OtcOrderRecord>> orders() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/otc/orders/me'),
      headers: await _headers(),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw OtcException(_message(decoded));
    return (decoded as List)
        .whereType<Map>()
        .map((row) => OtcOrderRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<OtcOrderRecord> submit(
    String offerId,
    int quantity,
    String key,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/otc/orders'),
      headers: await _headers(),
      body: jsonEncode({
        'offerId': offerId,
        'quantity': quantity,
        'transactionKey': key,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw OtcException(_message(decoded));
    return OtcOrderRecord.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  String _message(dynamic value) => value is Map && value['message'] != null
      ? value['message'].toString()
      : 'OTC request failed';
}

class OtcException implements Exception {
  const OtcException(this.message);
  final String message;
  @override
  String toString() => message;
}
