import '../widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/app_content_service.dart';
import '../services/client_account_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
import '../widgets/app_feedback.dart';

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
      padding: AppSpacing.page,
      children: [
        const AppText(
          'App content refreshes after your language preference is saved.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final entry in const [
          ('en', 'English', 'EN'),
          ('hi', 'हिन्दी', 'हि'),
        ])
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.zero,
            borderColor: AppLanguage.instance.code == entry.$1
                ? AppColors.brandPrimary
                : AppColors.divider,
            child: ListTile(
              minTileHeight: 64,
              enabled: !_saving,
              onTap: () => _select(entry.$1),
              leading: CircleAvatar(
                backgroundColor: AppColors.brandPrimarySoft,
                foregroundColor: AppColors.brandPrimary,
                child: Text(
                  entry.$3,
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.brandPrimary,
                  ),
                ),
              ),
              title: AppText(entry.$2, style: AppTypography.titleSmall),
              trailing: AppLanguage.instance.code == entry.$1
                  ? const Icon(Icons.check_circle, color: AppColors.gain)
                  : null,
            ),
          ),
        if (_saving) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppErrorView(title: _error!, compact: true),
          ),
      ],
    ),
  );
}
