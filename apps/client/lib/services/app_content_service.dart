import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../l10n/app_language.dart';

class AppContentBlock {
  const AppContentBlock({
    required this.body,
    this.title,
    this.locale = 'en',
  });

  final String body;
  final String? title;
  final String locale;

  factory AppContentBlock.fromJson(Map<String, dynamic> json) {
    return AppContentBlock(
      body: '${json['body'] ?? ''}',
      title: json['title']?.toString(),
      locale: '${json['locale'] ?? 'en'}',
    );
  }
}

class LegalDocumentContent {
  const LegalDocumentContent({
    required this.effective,
    required this.sections,
    this.title,
  });

  final String effective;
  final String? title;
  final List<({String heading, String body})> sections;

  factory LegalDocumentContent.fromBlock(AppContentBlock? block) {
    if (block == null || block.body.trim().isEmpty) {
      return const LegalDocumentContent(effective: '', sections: []);
    }
    try {
      final decoded = jsonDecode(block.body);
      if (decoded is! Map) {
        return LegalDocumentContent(effective: '', sections: [], title: block.title);
      }
      final sections = (decoded['sections'] is List ? decoded['sections'] as List : const [])
          .whereType<Map>()
          .map(
            (row) => (
              heading: '${row['heading'] ?? ''}',
              body: '${row['body'] ?? ''}',
            ),
          )
          .where((row) => row.heading.isNotEmpty || row.body.isNotEmpty)
          .toList();
      return LegalDocumentContent(
        effective: '${decoded['effective'] ?? ''}',
        sections: sections,
        title: block.title,
      );
    } catch (_) {
      return LegalDocumentContent(
        effective: '',
        sections: [(heading: block.title ?? '', body: block.body)],
        title: block.title,
      );
    }
  }
}

class AppContentBundle {
  const AppContentBundle({
    required this.home,
    required this.deposit,
    required this.support,
    required this.trading,
    required this.legal,
    required this.about,
    required this.insights,
    this.updatedAt,
  });

  final Map<String, AppContentBlock> home;
  final Map<String, AppContentBlock> deposit;
  final Map<String, AppContentBlock> support;
  final Map<String, AppContentBlock> trading;
  final Map<String, AppContentBlock> legal;
  final Map<String, AppContentBlock> about;
  final Map<String, AppContentBlock> insights;
  final DateTime? updatedAt;

  static const empty = AppContentBundle(
    home: {},
    deposit: {},
    support: {},
    trading: {},
    legal: {},
    about: {},
    insights: {},
  );

  bool get hasContent =>
      home.isNotEmpty ||
      deposit.isNotEmpty ||
      support.isNotEmpty ||
      trading.isNotEmpty ||
      legal.isNotEmpty ||
      about.isNotEmpty ||
      insights.isNotEmpty;

  Map<String, AppContentBlock> _module(String module) => switch (module) {
        'home' => home,
        'deposit' => deposit,
        'support' => support,
        'trading' => trading,
        'legal' => legal,
        'about' => about,
        'insights' => insights,
        _ => const <String, AppContentBlock>{},
      };

  String text(String module, String key, {String fallback = ''}) {
    final value = _module(module)[key]?.body.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  String? title(String module, String key) {
    final value = _module(module)[key]?.title?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  LegalDocumentContent privacyDocument() =>
      LegalDocumentContent.fromBlock(legal['privacy.document']);

  LegalDocumentContent termsDocument() =>
      LegalDocumentContent.fromBlock(legal['terms.document']);

  List<AppContentBlock> insightArticles() {
    final articles = insights.entries
        .where((entry) => entry.key.startsWith('article.'))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return articles.map((entry) => entry.value).toList();
  }

  factory AppContentBundle.fromJson(Map<String, dynamic> json) {
    Map<String, AppContentBlock> parseModule(dynamic value) {
      if (value is! Map) return {};
      return value.map(
        (key, item) => MapEntry(
          '$key',
          AppContentBlock.fromJson(
            item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{'body': '$item'},
          ),
        ),
      );
    }

    final deposit = json['deposit'];
    final depositMap = deposit is Map
        ? Map<String, dynamic>.from(deposit)
        : <String, dynamic>{};
    // Legacy residual field from removed self-serve receiving accounts.
    depositMap.remove('receivingAccounts');
    final updatedAtRaw = json['updatedAt']?.toString();

    return AppContentBundle(
      home: parseModule(json['home']),
      deposit: parseModule(depositMap),
      support: parseModule(json['support']),
      trading: parseModule(json['trading']),
      legal: parseModule(json['legal']),
      about: parseModule(json['about']),
      insights: parseModule(json['insights']),
      updatedAt: updatedAtRaw == null ? null : DateTime.tryParse(updatedAtRaw),
    );
  }
}

class AppContentService extends ChangeNotifier {
  AppContentService._();

  static final AppContentService instance = AppContentService._();

  AppContentBundle _bundle = AppContentBundle.empty;
  DateTime? _loadedAt;
  Future<AppContentBundle>? _inFlight;
  int _fetchGeneration = 0;

  AppContentBundle get current => _bundle;

  Future<AppContentBundle> load({bool force = false}) async {
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5) &&
        _bundle.hasContent) {
      return _bundle;
    }
    if (!force) {
      final existing = _inFlight;
      if (existing != null) return existing;
    }

    final future = _fetch();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    }
  }

  Future<AppContentBundle> _fetch() async {
    final locale = AppLanguage.instance.code == 'hi' ? 'hi' : 'en';
    final generation = ++_fetchGeneration;
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/app-content?locale=$locale'),
          )
          .timeout(const Duration(seconds: 12));
      if (generation != _fetchGeneration) return _bundle;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _bundle;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return _bundle;
      _bundle = AppContentBundle.fromJson(Map<String, dynamic>.from(decoded));
      _loadedAt = DateTime.now();
      notifyListeners();
      return _bundle;
    } catch (_) {
      return _bundle;
    }
  }
}
