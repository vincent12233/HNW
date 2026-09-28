part of 'market_page.dart';

extension _MarketHomeAccountSection on _MarketHomePageState {
  Widget _profileHeader() {
    return ProfileIdentityHeader(
      name: accountName,
      accountNumber: accountNumber,
      phone: accountPhone,
      kycStatus: kycStatus,
      clientTier: _profileData['clientTier']?.toString() ?? '--',
      memberSince:
          _profileData['createdAt']?.toString().split('T').first ?? '--',
      accountStatus: _profileData['status']?.toString() ?? '--',
      avatarBytes: profileAvatarBytes,
      onAvatarTap: _pickProfileAvatar,
      onEdit: _editProfile,
    );
  }

  Widget _accountBody() {
    final holdingsValue = positions.values
        .where((position) => portfolioCategory(position.category) != null)
        .fold<double>(0, (total, position) {
          final stock = _stockForOrNull(
            position.symbol,
            exchange: position.exchange,
          );
          return total +
              position.marketValue(stock?.price ?? position.averageCost);
        });

    final productValue = holdingsValue;
    final totalReturns = positions.values
        .where((position) => portfolioCategory(position.category) != null)
        .fold<double>(0, (total, position) {
          final stock = _stockForOrNull(
            position.symbol,
            exchange: position.exchange,
          );
          return total +
              position.realizedProfitLoss +
              position.unrealizedProfitLoss(
                stock?.price ?? position.averageCost,
              );
        });

    final horizontalPadding = MediaQuery.sizeOf(context).width < 360
        ? AppSpacing.md + 2
        : AppSpacing.lg;
    return AppFadeIn(
      switchKey: 'profile|$accountNumber|$kycStatus|${_profileData['status']}',
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.md + 2,
          horizontalPadding,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: AppText(
                  _appContent.text(
                    'home',
                    'profile.page_title',
                    fallback: 'Profile',
                  ),
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Search stocks'),
                onPressed: _openStockSearch,
                icon: const Icon(Icons.search_rounded, size: 22),
              ),
              Builder(
                builder: (scaffoldContext) => IconButton(
                  key: const ValueKey('profile-settings-button'),
                  tooltip: tr('Settings'),
                  onPressed: () => Scaffold.of(scaffoldContext).openEndDrawer(),
                  icon: const Icon(Icons.settings_outlined, size: 22),
                ),
              ),
              _notificationButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          _profileHeader(),
          const SizedBox(height: AppSpacing.lg),
          AppText(
            _appContent.text(
              'home',
              'profile.section.overview',
              fallback: 'Account Overview',
            ),
            style: AppUi.sectionTitle,
          ),
          const SizedBox(height: AppSpacing.md),
          _accountDataStatus(),
          AppCard(
            radius: AppRadius.md,
            child: AccountMetrics(
              items: [
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.available',
                    fallback: 'Available Balance',
                  ),
                  _balanceText(availableBalance),
                ),
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.portfolio',
                    fallback: 'Product Holdings',
                  ),
                  _balanceText(productValue),
                ),
                AccountMetric(
                  _appContent.text(
                    'home',
                    'profile.metric.returns',
                    fallback: 'Total Returns',
                  ),
                  _balanceText(totalReturns, signed: true),
                  color: _amountsHidden || !_accountSnapshotLoaded
                      ? AppColors.textPrimary
                      : totalReturns >= 0
                      ? AppColors.gain
                      : AppColors.loss,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.account',
              fallback: 'Account',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.person_outline_rounded,
                title: 'Personal Information',
                onTap: _editProfile,
                color: AppColors.brandPrimary,
              ),
              ProfileMenuRow(
                icon: Icons.verified_user_outlined,
                title: 'KYC Verification',
                status: profileKycLabel(kycStatus),
                statusColor: kycStatus == 'APPROVED'
                    ? AppColors.gain
                    : kycStatus == 'REJECTED'
                    ? AppColors.loss
                    : AppColors.warning,
                onTap: () => _openAccountSettings('kyc'),
                color: AppColors.gain,
              ),
              ProfileMenuRow(
                icon: Icons.account_balance_outlined,
                title: 'Bank Accounts',
                onTap: () => _openAccountSettings('banks'),
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.funds',
              fallback: 'Funds',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.request_quote_outlined,
                title: 'Loan Applications',
                color: AppColors.gain,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoanPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl - 2),
          ProfileSection(
            title: _appContent.text(
              'home',
              'profile.section.support',
              fallback: 'Support & Education',
            ),
            children: [
              ProfileMenuRow(
                icon: Icons.help_outline,
                title: _appContent.text(
                  'home',
                  'profile.tile.help.title',
                  fallback: 'Help & Support',
                ),
                onTap: () => unawaited(
                  showSupportChatPanel(
                    context,
                    initialMessage: _appContent.text(
                      'support',
                      'chat_preset.help',
                      fallback: 'Hello, I need help with my account.',
                    ),
                  ),
                ),
                color: AppColors.brandPrimary,
              ),
              ProfileMenuRow(
                icon: Icons.menu_book_outlined,
                title: _appContent.text(
                  'home',
                  'profile.tile.insights.title',
                  fallback: 'Wealth Insights',
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WealthInsightsPage(),
                  ),
                ),
                color: AppColors.gain,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md + 2),
          AppText(
            AppConfig.appName,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _closeSettingsAnd(VoidCallback action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  void _editProfile() {
    _openAccountSettings('profile');
  }

  Future<void> _openAccountSettings(String section) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountSettingsPage(section: section),
      ),
    );
    if (!mounted) return;
    if (changed == true || section == 'profile') {
      final session = await AuthService().restoreSession();
      if (!mounted) return;
      _updateState(() {
        accountName = session?.fullName.isNotEmpty == true
            ? session!.fullName
            : accountName;
      });
    }
    if (section == 'kyc' && accountPhone.isNotEmpty) {
      final refreshedStatus = await AuthService().fetchKycStatus();
      if (mounted) _updateState(() => kycStatus = refreshedStatus);
    }
  }

  void _openAbout() {
    final company = _appContent.text(
      'about',
      'company_name',
      fallback: AppConfig.appName,
    );
    final marketingVersion = _appContent.text('about', 'app_version');
    final legalName = _appContent.text('about', 'legal_name');
    final address = _appContent.text('about', 'registered_address');
    final grievance = _appContent.text('about', 'grievance_contact');
    final summary = _appContent.text('about', 'summary');

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  company,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                AppText('App version ${AppConfig.appVersion}'),
                if (marketingVersion.isNotEmpty &&
                    marketingVersion != 'Version ${AppConfig.appVersion}' &&
                    marketingVersion != AppConfig.appVersion) ...[
                  const SizedBox(height: 4),
                  AppText(
                    marketingVersion,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppText(
                    summary,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
                if (legalName.isNotEmpty ||
                    address.isNotEmpty ||
                    grievance.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  if (legalName.isNotEmpty)
                    AppText(
                      legalName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(address),
                  ],
                  if (grievance.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    AppText(grievance),
                  ],
                ],
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: const AppText('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Terms'),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const AppText('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LegalPage(title: 'Privacy'),
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const AppText('Risk Disclosure'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            const LegalPage(title: 'Risk Disclosure'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSignOut() {
    if (_signingOut) return;
    var started = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('Sign out?'),
        content: const AppText(
          'Your account data is saved on this '
          'device and will be restored after '
          'you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (started) return;
              Navigator.pop(dialogContext);
            },
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (started || _signingOut) return;
              started = true;
              _updateState(() => _signingOut = true);
              Navigator.pop(dialogContext);
              await AuthService().clearSession();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => LoginPage(
                    onSignedIn: (_) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const MarketHomePage(),
                        ),
                      );
                    },
                  ),
                ),
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const AppText('Sign Out'),
          ),
        ],
      ),
    );
  }
}
