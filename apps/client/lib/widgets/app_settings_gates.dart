import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_language.dart';
import '../services/app_client_settings_service.dart';
import '../services/app_version.dart';
import '../theme/app_colors.dart';

class ForceUpdatePage extends StatelessWidget {
  const ForceUpdatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppClientSettingsService.instance;
    final settings = service.settings;
    final updateUri = settings.validUpdateUri;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.system_update,
                size: 56,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 16),
              AppText(
                'Update required',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AppText(
                'This version is below the minimum supported release. Please update to continue.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _MetaRow(label: 'Current', value: service.currentVersion),
              _MetaRow(label: 'Required', value: settings.minVersion),
              _MetaRow(label: 'Latest', value: settings.latestVersion),
              const SizedBox(height: 12),
              if (updateUri == null)
                AppText(
                  'No update download link is configured for this platform. You can continue for now, or contact support separately.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              const Spacer(),
              if (updateUri != null)
                FilledButton(
                  onPressed: () async {
                    await launchUrl(
                      updateUri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const AppText('Update'),
                )
              else
                FilledButton(
                  onPressed: () => service.continueWithoutUpdateDestination(),
                  child: const AppText('Continue'),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => service.refresh(force: true),
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppClientSettingsService.instance;
    final message = service.settings.maintenanceMessage?.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.engineering_outlined,
                size: 56,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 16),
              AppText(
                'Under maintenance',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AppText(
                (message == null || message.isEmpty)
                    ? 'The app is temporarily unavailable. Please try again shortly.'
                    : message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => service.refresh(force: true),
                child: const AppText('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Optional update dialog — once per app session after dismiss.
Future<void> maybeShowOptionalUpdateDialog(BuildContext context) async {
  final service = AppClientSettingsService.instance;
  if (service.gate != AppSettingsGate.optionalUpdate) return;
  if (service.optionalUpdateDismissed) return;
  if (!context.mounted) return;

  final updateUri = service.settings.validUpdateUri;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const AppText('Update available'),
        content: AppText(
          'A newer version (${service.settings.latestVersion}) is available. You are on ${service.currentVersion}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              service.dismissOptionalUpdate();
              Navigator.of(ctx).pop();
            },
            child: const AppText('Later'),
          ),
          if (updateUri != null)
            TextButton(
              onPressed: () async {
                await launchUrl(
                  updateUri,
                  mode: LaunchMode.externalApplication,
                );
                service.dismissOptionalUpdate();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const AppText('Update'),
            )
          else
            TextButton(
              onPressed: () {
                service.dismissOptionalUpdate();
                Navigator.of(ctx).pop();
              },
              child: const AppText('OK'),
            ),
        ],
      );
    },
  );
}
