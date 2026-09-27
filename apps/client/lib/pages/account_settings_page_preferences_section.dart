part of 'account_settings_page.dart';

extension _AccountSettingsPreferencesSection on _AccountSettingsPageState {
  Widget _preferences() {
    final preferences = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    const labels = {
      'orderNotifications': 'Order notifications',
      'accountNotifications': 'Account notifications',
      'supportNotifications': 'Customer service notifications',
    };
    return ListView(
      padding: AppSpacing.page,
      children: [
        const AppText(
          'These switches save to the server. A failed change is not kept as saved.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final entry in labels.entries)
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              title: AppText(entry.value, style: AppTypography.titleSmall),
              subtitle: const AppText(
                'Receive updates for this activity',
                style: AppTypography.caption,
              ),
              secondary: _savingPreferences.contains(entry.key)
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Saving preference',
                      ),
                    )
                  : Icon(switch (entry.key) {
                      'orderNotifications' => Icons.receipt_long_outlined,
                      'accountNotifications' => Icons.person_outline,
                      _ => Icons.support_agent_outlined,
                    }, color: AppColors.brandPrimary),
              value: preferences[entry.key] == true,
              onChanged: _savingPreferences.contains(entry.key)
                  ? null
                  : (value) async {
                      if (_savingPreferences.contains(entry.key)) return;
                      _setState(() => _savingPreferences.add(entry.key));
                      try {
                        await service.updatePreferences({entry.key: value});
                        if (mounted) {
                          _setState(
                            () => data = {
                              if (data is Map)
                                ...Map<String, dynamic>.from(data as Map),
                              entry.key: value,
                            },
                          );
                        }
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: AppText(clientErrorMessage(error)),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) {
                          _setState(
                            () => _savingPreferences.remove(entry.key),
                          );
                        }
                      }
                    },
            ),
          ),
      ],
    );
  }
}