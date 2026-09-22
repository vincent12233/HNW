import '../widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/client_account_service.dart';
import '../theme/appearance_settings.dart';
import '../theme/app_motion.dart';
import '../widgets/app_feedback.dart';
import '../utils/client_error_message.dart';

class AppearancePage extends StatefulWidget {
  const AppearancePage({super.key});
  @override
  State<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<AppearancePage> {
  bool _busy = false;
  String? _error;
  Future<void> _select(String value) async {
    if (_busy || value == AppearanceSettings.instance.value) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ClientAccountService().updatePreferences({'theme': value});
      await AppearanceSettings.instance.select(value);
    } catch (error) {
      if (mounted) setState(() => _error = clientErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    appBar: AppBar(title: const AppText('Appearance')),
    body: ListView(
      children: [
        if (_busy) const LinearProgressIndicator(),
        for (final option in {
          'light': 'Light Theme',
          'highContrast': 'High contrast',
        }.entries)
          ListTile(
            title: AppText(option.value),
            selected: AppearanceSettings.instance.value == option.key,
            enabled: !_busy,
            onTap: () => _select(option.key),
            minTileHeight: AppMotion.tapTarget,
            trailing: AppearanceSettings.instance.value == option.key
                ? const Icon(Icons.check)
                : null,
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppErrorView(title: _error!, compact: true),
          ),
      ],
    ),
  );
}
