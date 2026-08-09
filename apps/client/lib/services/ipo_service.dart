import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/ipo.dart';
import 'auth_service.dart';

class IpoService {
  final AuthService _authService = AuthService();

  Future<List<Ipo>> fetchOpenIpos() async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) return <Ipo>[];

    final response = await http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/ipo/open'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 6));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IpoException(_apiMessage(decoded, 'Unable to load IPOs'));
    }

    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return <Ipo>[];

    return data
        .map((item) => Ipo.fromApiJson(Map<String, dynamic>.from(item as Map)))
        .where((ipo) => ipo.id.isNotEmpty)
        .toList();
  }

  Future<List<IpoApplication>> fetchMyApplications() async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      return <IpoApplication>[];
    }

    final response = await http
        .get(
          Uri.parse('${AppConfig.apiBaseUrl}/ipo/applications/me'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 6));

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IpoException(_apiMessage(decoded, 'Unable to load applications'));
    }

    final data = decoded is Map ? decoded['data'] : null;
    if (data is! List) return <IpoApplication>[];

    return data
        .map(
          (item) =>
              IpoApplication.fromApiJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((application) => application.id.isNotEmpty)
        .toList();
  }

  Future<IpoApplication?> apply(String ipoId) async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw const IpoException('Please sign in again');
    }

    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/ipo/$ipoId/apply'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IpoException(_apiMessage(decoded, 'IPO application failed'));
    }

    if (decoded is Map && decoded['canApply'] == false) {
      throw const IpoException('Maximum IPO applications reached');
    }

    await fetchMyApplications();
    return null;
  }
}

class IpoException implements Exception {
  const IpoException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _apiMessage(dynamic decoded, String fallback) {
  if (decoded is Map && decoded['message'] != null) {
    return decoded['message'].toString();
  }
  return fallback;
}
