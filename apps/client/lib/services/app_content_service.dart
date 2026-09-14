import 'dart:convert';

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

class DepositReceivingAccountInfo {
  const DepositReceivingAccountInfo({
    required this.id,
    required this.label,
    required this.method,
    this.accountName,
    this.bankName,
    this.accountNumber,
    this.ifsc,
    this.upiId,
    this.notes,
  });

  final String id;
  final String label;
  final String method;
  final String? accountName;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;
  final String? upiId;
  final String? notes;

  factory DepositReceivingAccountInfo.fromJson(Map<String, dynamic> json) {
    return DepositReceivingAccountInfo(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? ''}',
      method: '${json['method'] ?? ''}',
      accountName: json['accountName']?.toString(),
      bankName: json['bankName']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      ifsc: json['ifsc']?.toString(),
      upiId: json['upiId']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class AppContentBundle {
  const AppContentBundle({
    required this.home,
    required this.deposit,
    required this.support,
    required this.trading,
    this.receivingAccounts = const [],
  });

  final Map<String, AppContentBlock> home;
  final Map<String, AppContentBlock> deposit;
  final Map<String, AppContentBlock> support;
  final Map<String, AppContentBlock> trading;
  final List<DepositReceivingAccountInfo> receivingAccounts;

  static const empty = AppContentBundle(
    home: {},
    deposit: {},
    support: {},
    trading: {},
  );

  String text(
    String module,
    String key, {
    String fallback = '',
  }) {
    final map = switch (module) {
      'home' => home,
      'deposit' => deposit,
      'support' => support,
      'trading' => trading,
      _ => const <String, AppContentBlock>{},
    };
    final value = map[key]?.body.trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  String? title(String module, String key) {
    final map = switch (module) {
      'trading' => trading,
      'home' => home,
      'deposit' => deposit,
      'support' => support,
      _ => const <String, AppContentBlock>{},
    };
    final value = map[key]?.title?.trim();
    return (value == null || value.isEmpty) ? null : value;
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
    final accountsRaw = depositMap['receivingAccounts'];
    depositMap.remove('receivingAccounts');

    return AppContentBundle(
      home: parseModule(json['home']),
      deposit: parseModule(depositMap),
      support: parseModule(json['support']),
      trading: parseModule(json['trading']),
      receivingAccounts: accountsRaw is List
          ? accountsRaw
                .whereType<Map>()
                .map(
                  (row) => DepositReceivingAccountInfo.fromJson(
                    Map<String, dynamic>.from(row),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class AppContentService {
  AppContentService._();

  static final AppContentService instance = AppContentService._();

  AppContentBundle _bundle = AppContentBundle.empty;
  DateTime? _loadedAt;
  Future<AppContentBundle>? _inFlight;

  AppContentBundle get current => _bundle;

  Future<AppContentBundle> load({bool force = false}) async {
    if (!force &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5) &&
        _bundle.home.isNotEmpty) {
      return _bundle;
    }
    final existing = _inFlight;
    if (existing != null) return existing;

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
    try {
      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/app-content?locale=$locale'),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _bundle;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return _bundle;
      _bundle = AppContentBundle.fromJson(Map<String, dynamic>.from(decoded));
      _loadedAt = DateTime.now();
      return _bundle;
    } catch (_) {
      return _bundle;
    }
  }
}
