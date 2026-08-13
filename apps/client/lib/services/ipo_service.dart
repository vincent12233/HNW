import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models/ipo.dart';
import 'auth_service.dart';
import 'local_data_cache.dart';
import 'session_expiry_service.dart';

class IpoService {
  final AuthService _authService = AuthService();
  final SessionExpiryService _sessionExpiry = SessionExpiryService();

  Future<List<Ipo>> fetchOpenIpos() async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) return <Ipo>[];

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/ipo/open'),
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));

      if (_sessionExpiry.isUnauthorized(response.statusCode)) {
        await _sessionExpiry.expire();
        return <Ipo>[];
      }

      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IpoException(_apiMessage(decoded, 'Unable to load IPOs'));
      }

      final data = decoded is Map ? decoded['data'] : null;
      if (data is! List) return _cachedOpenIpos();

      await LocalDataCache.saveJson(LocalDataCache.openIpos, data);

      return _iposFromRows(data);
    } catch (_) {
      return _cachedOpenIpos();
    }
  }

  Future<List<IpoApplication>> fetchMyApplications() async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      return <IpoApplication>[];
    }

    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/ipo/applications/me'),
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          )
          .timeout(const Duration(seconds: 6));

      if (_sessionExpiry.isUnauthorized(response.statusCode)) {
        await _sessionExpiry.expire();
        return <IpoApplication>[];
      }

      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw IpoException(_apiMessage(decoded, 'Unable to load applications'));
      }

      final data = decoded is Map ? decoded['data'] : null;
      if (data is! List) return _cachedApplications();

      await LocalDataCache.saveJson(LocalDataCache.ipoApplications, data);

      return _applicationsFromRows(data);
    } catch (_) {
      return _cachedApplications();
    }
  }

  Future<IpoApplication?> apply(String ipoId) async {
    final session = await _authService.restoreSession();
    if (session == null || session.accessToken.isEmpty) {
      throw const IpoException('Please sign in again');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/ipo/$ipoId/apply'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        )
        .timeout(const Duration(seconds: 10));

    if (_sessionExpiry.isUnauthorized(response.statusCode)) {
      await _sessionExpiry.expire();
      throw const IpoException('Please sign in again');
    }

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

Future<List<Ipo>> _cachedOpenIpos() async {
  final cached = await LocalDataCache.readJson(LocalDataCache.openIpos);

  if (cached is List) {
    return _iposFromRows(cached);
  }

  return <Ipo>[];
}

Future<List<IpoApplication>> _cachedApplications() async {
  final cached = await LocalDataCache.readJson(LocalDataCache.ipoApplications);

  if (cached is List) {
    return _applicationsFromRows(cached);
  }

  return <IpoApplication>[];
}

List<Ipo> _iposFromRows(List<dynamic> rows) {
  return rows
      .map((item) => Ipo.fromApiJson(Map<String, dynamic>.from(item as Map)))
      .where((ipo) => ipo.id.isNotEmpty)
      .toList();
}

List<IpoApplication> _applicationsFromRows(List<dynamic> rows) {
  return rows
      .map(
        (item) =>
            IpoApplication.fromApiJson(Map<String, dynamic>.from(item as Map)),
      )
      .where((application) => application.id.isNotEmpty)
      .toList();
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
