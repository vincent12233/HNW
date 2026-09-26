import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../l10n/app_language.dart';
import 'insight_articles_service.dart';

/// Extends [InsightArticlesService] with success-vs-failure semantics.
extension InsightArticlesFetch on InsightArticlesService {
  /// Distinguishes API SUCCESS [] from FAILURE.
  Future<({bool ok, List<InsightArticle> articles})> listResult({
    String? locale,
  }) async {
    final code = locale ?? AppLanguage.instance.code;
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/insights?locale=$code'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (ok: false, articles: const <InsightArticle>[]);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        return (ok: false, articles: const <InsightArticle>[]);
      }
      final articles = decoded
          .whereType<Map>()
          .map((row) => InsightArticle.fromJson(Map<String, dynamic>.from(row)))
          .where((row) => row.title.trim().isNotEmpty)
          .toList();
      return (ok: true, articles: articles);
    } catch (_) {
      return (ok: false, articles: const <InsightArticle>[]);
    }
  }
}
