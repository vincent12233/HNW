part of 'market_page.dart';

extension _MarketProfileSettingsDrawer on _MarketHomePageState {
  Widget _profileSettingsDrawer() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 600
        ? math.min(screenWidth * 0.5, 520.0)
        : math.min(screenWidth * 0.86, 380.0);
    return Drawer(
      key: const ValueKey('profile-settings-drawer'),
      width: drawerWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        'Settings',
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppText(
                        'Manage security, preferences and account policies',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-profile-settings'),
                  tooltip: tr('Close settings'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Divider(height: 1),
            ),
            const SizedBox(height: AppSpacing.lg),
            ProfileSection(
              title: _appContent.text(
                'home',
                'profile.section.security',
                fallback: 'Security',
              ),
              children: [
                ProfileMenuRow(
                  icon: Icons.password_outlined,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountSecurityPage(),
                      ),
                    ),
                  ),
                  color: AppColors.brandPrimary,
                ),
                ProfileMenuRow(
                  icon: Icons.security_outlined,
                  title: 'Two-Factor Authentication',
                  subtitle: 'Authenticator and recovery codes',
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TwoFactorPage(),
                      ),
                    ),
                  ),
                  color: AppColors.info,
                ),
                ProfileMenuRow(
                  icon: Icons.pin_outlined,
                  title: 'Transaction PIN',
                  subtitle: 'Set or change your withdrawal password',
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const AccountSecurityPage(withdrawalPin: true),
                      ),
                    ),
                  ),
                  color: AppColors.warning,
                ),
                if (_biometricCapability != null)
                  ProfileMenuRow(
                    icon: _biometricCapability == DeviceBiometric.face
                        ? Icons.face_retouching_natural_outlined
                        : Icons.fingerprint,
                    title: 'Biometric quick login',
                    subtitle: _biometricCapability == DeviceBiometric.face
                        ? 'Face ID'
                        : 'Fingerprint',
                    color: AppColors.info,
                    trailing: Switch.adaptive(
                      value: _biometricEnabled,
                      onChanged: _biometricBusy
                          ? null
                          : _setBiometricQuickLogin,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl - 2),
            ProfileSection(
              title: _appContent.text(
                'home',
                'profile.section.preferences',
                fallback: 'Preferences',
              ),
              children: [
                ProfileMenuRow(
                  icon: Icons.notifications_none_rounded,
                  title: 'Alert Preferences',
                  subtitle: 'Choose which account updates you receive',
                  onTap: () => _closeSettingsAnd(
                    () => _openAccountSettings('preferences'),
                  ),
                  color: AppColors.brandPrimary,
                ),
                ProfileMenuRow(
                  icon: Icons.contrast,
                  title: 'Appearance',
                  subtitle: 'Light or high contrast display',
                  status: AppearanceSettings.instance.value == 'highContrast'
                      ? 'High contrast'
                      : 'Light',
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AppearancePage(),
                      ),
                    ),
                  ),
                  color: AppColors.textSecondary,
                ),
                ProfileMenuRow(
                  icon: Icons.language_rounded,
                  title: 'Language',
                  subtitle: 'Choose your preferred language',
                  status: appLanguageName(AppLanguage.instance.code),
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LanguagePage(),
                      ),
                    ),
                  ),
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl - 2),
            ProfileSection(
              title: _appContent.text(
                'home',
                'profile.section.legal',
                fallback: 'Legal',
              ),
              children: [
                ProfileMenuRow(
                  icon: Icons.info_outline_rounded,
                  title: _appContent.text(
                    'home',
                    'profile.tile.about.title',
                    fallback: 'About Us',
                  ),
                  onTap: () => _closeSettingsAnd(_openAbout),
                  color: AppColors.brandPrimary,
                ),
                ProfileMenuRow(
                  icon: Icons.description_outlined,
                  title: _appContent.text(
                    'home',
                    'profile.tile.terms.title',
                    fallback: 'Terms & Conditions',
                  ),
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Terms'),
                      ),
                    ),
                  ),
                  color: AppColors.textSecondary,
                ),
                ProfileMenuRow(
                  icon: Icons.privacy_tip_outlined,
                  title: _appContent.text(
                    'home',
                    'profile.tile.privacy.title',
                    fallback: 'Privacy Policy',
                  ),
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Privacy'),
                      ),
                    ),
                  ),
                  color: AppColors.textSecondary,
                ),
                ProfileMenuRow(
                  icon: Icons.warning_amber_rounded,
                  title: _appContent.text(
                    'home',
                    'profile.tile.risk.title',
                    fallback: 'Risk Disclosure',
                  ),
                  onTap: () => _closeSettingsAnd(
                    () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const LegalPage(title: 'Risk Disclosure'),
                      ),
                    ),
                  ),
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl - 2),
            AppCard(
              padding: EdgeInsets.zero,
              child: ProfileMenuRow(
                icon: Icons.logout_rounded,
                title: _appContent.text(
                  'home',
                  'profile.logout_label',
                  fallback: 'Logout',
                ),
                subtitle: _appContent.text(
                  'home',
                  'profile.logout_subtitle',
                  fallback: 'Securely logout from your account',
                ),
                onTap: () => _closeSettingsAnd(_confirmSignOut),
                destructive: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}