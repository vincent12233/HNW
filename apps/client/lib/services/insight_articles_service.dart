import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../l10n/app_language.dart';

class InsightArticle {
  const InsightArticle({
    required this.id,
    required this.slug,
    required this.locale,
    required this.title,
    required this.body,
    this.summary,
    this.imageUrl,
    this.sortOrder = 0,
    this.publishedAt,
  });

  final String id;
  final String slug;
  final String locale;
  final String title;
  final String body;
  final String? summary;
  final String? imageUrl;
  final int sortOrder;
  final DateTime? publishedAt;

  factory InsightArticle.fromJson(Map<String, dynamic> json) {
    return InsightArticle(
      id: '${json['id'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      locale: '${json['locale'] ?? 'en'}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      summary: json['summary']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      sortOrder: int.tryParse('${json['sortOrder'] ?? 0}') ?? 0,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse('${json['publishedAt']}'),
    );
  }
}

/// Structured insights API with safe empty result on failure.
class InsightArticlesService {
  InsightArticlesService._();

  static final InsightArticlesService instance = InsightArticlesService._();

  Future<List<InsightArticle>> list({String? locale}) async {
    final code = locale ?? (AppLanguage.instance.code == 'hi' ? 'hi' : 'en');
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/insights?locale=$code'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((row) => InsightArticle.fromJson(Map<String, dynamic>.from(row)))
          .where((row) => row.title.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<InsightArticle?> bySlug(String slug, {String? locale}) async {
    final code = locale ?? (AppLanguage.instance.code == 'hi' ? 'hi' : 'en');
    try {
      final response = await http
          .get(
            Uri.parse(
              '${AppConfig.apiBaseUrl}/insights/${Uri.encodeComponent(slug)}?locale=$code',
            ),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return InsightArticle.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
