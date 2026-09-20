import '../widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/client_account_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';

class LanguagePage extends StatefulWidget {
  const LanguagePage({super.key, this.accountService});
  final ClientAccountService? accountService;
  @override
  State<LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<LanguagePage> {
  bool _saving = false;
  String? _error;
  Future<void> _select(String value) async {
    if (_saving || value == AppLanguage.instance.code) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.accountService ?? ClientAccountService()).updatePreferences(
        {'language': value},
      );
      await AppLanguage.instance.select(value);
      await AppContentService.instance.load(force: true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to save language');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    appBar: AppBar(title: const AppText('Language')),
    body: ListView(
      children: [
        for (final entry in {'en': 'English', 'hi': 'हिन्दी'}.entries)
          ListTile(
            title: Text(entry.value),
            minTileHeight: AppMotion.tapTarget,
            trailing: AppLanguage.instance.code == entry.key
                ? const Icon(Icons.check, color: AppColors.gain)
                : null,
            enabled: !_saving,
            onTap: () => _select(entry.key),
          ),
        if (_saving) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(16), child: AppText(_error!)),
      ],
    ),
  );
}
