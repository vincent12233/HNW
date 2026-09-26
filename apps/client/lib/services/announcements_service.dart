import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../l10n/app_language.dart';

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.locale,
    required this.title,
    required this.body,
    required this.type,
    this.priority = 0,
    this.sortOrder = 0,
    this.startsAt,
    this.endsAt,
  });

  final String id;
  final String locale;
  final String title;
  final String body;
  final String type;
  final int priority;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    return AnnouncementItem(
      id: '${json['id'] ?? ''}',
      locale: '${json['locale'] ?? 'en'}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      type: '${json['type'] ?? 'GENERAL'}',
      priority: int.tryParse('${json['priority'] ?? 0}') ?? 0,
      sortOrder: int.tryParse('${json['sortOrder'] ?? 0}') ?? 0,
      startsAt: json['startsAt'] == null
          ? null
          : DateTime.tryParse('${json['startsAt']}'),
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.tryParse('${json['endsAt']}'),
    );
  }
}

/// Data-only announcements client (no Home UI in Phase 11B).
class AnnouncementsService {
  AnnouncementsService._();

  static final AnnouncementsService instance = AnnouncementsService._();

  Future<List<AnnouncementItem>> list({String? locale}) async {
    final code = locale ?? AppLanguage.instance.code;
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/announcements?locale=$code'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (row) => AnnouncementItem.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
