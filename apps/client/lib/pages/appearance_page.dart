import '../widgets/app_page_scaffold.dart';
import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/client_account_service.dart';
import '../theme/appearance_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/app_card.dart';
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
      padding: AppSpacing.page,
      children: [
        if (_busy) const LinearProgressIndicator(),
        const AppText(
          'Choose how information and controls appear throughout the app.',
          style: AppTypography.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final option in const [
          (
            'light',
            'Light Theme',
            'Balanced colors for everyday use',
            Icons.light_mode_outlined,
          ),
          (
            'highContrast',
            'High contrast',
            'Stronger borders and text contrast',
            Icons.contrast_rounded,
          ),
        ])
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            borderColor: AppearanceSettings.instance.value == option.$1
                ? AppColors.brandPrimary
                : AppColors.divider,
            onTap: _busy ? null : () => _select(option.$1),
            child: Row(
              children: [
                Icon(option.$4, color: AppColors.brandPrimary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(option.$2, style: AppTypography.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      AppText(option.$3, style: AppTypography.caption),
                    ],
                  ),
                ),
                if (AppearanceSettings.instance.value == option.$1)
                  const Icon(Icons.check_circle, color: AppColors.gain),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: AppErrorView(title: _error!, compact: true),
          ),
      ],
    ),
  );
}
