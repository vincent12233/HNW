part of 'market_page.dart';

extension _MarketHomeAccountActions on _MarketHomePageState {
  void _onDestinationSelected(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    _updateState(() {
      _previousSelectedIndex = selectedIndex;
      selectedIndex = index;
    });

    if (index == 3) {
      unawaited(_loadPortfolioHistory(_portfolioPeriod));
      unawaited(_refreshAccountSnapshot());
    }

    if (index == 1) {
      unawaited(_refreshMarketData());
    }

    if (index == 4) {
      unawaited(_refreshMembership());
      unawaited(_refreshUnreadNotificationCount());
      unawaited(_refreshAccountSnapshot());
      unawaited(_loadBiometricSettings());
    }

    if (index == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _showPendingIpoAllocationIfNeeded();
      });
    }
  }

  Future<void> _refreshMembership() async {
    try {
      final profile = await ClientAccountService().profile();
      if (!mounted) return;
      _updateState(() => _profileData = profile);
    } catch (_) {
      // Retain the last server-confirmed profile during a network interruption.
    }
  }

  Future<void> _loadBiometricSettings() async {
    final capability = await DeviceBiometrics.available();
    var enabled = false;
    if (capability != null) {
      final token = await AuthService().restoreBiometricToken();
      enabled = token != null && token.isNotEmpty;
    }
    if (!mounted) return;
    _updateState(() {
      _biometricCapability = capability;
      _biometricEnabled = enabled;
    });
  }

  Future<void> _setBiometricQuickLogin(bool enable) async {
    if (_biometricBusy || _biometricCapability == null) return;
    _updateState(() => _biometricBusy = true);
    try {
      if (enable) {
        final verified = await LocalAuthentication().authenticate(
          localizedReason: 'Enable biometric quick login',
          biometricOnly: true,
          persistAcrossBackgrounding: true,
        );
        if (!verified) return;
        await AuthService().enableBiometricQuickLogin();
        if (mounted) _updateState(() => _biometricEnabled = true);
      } else {
        await AuthService().disableBiometricQuickLogin();
        if (mounted) _updateState(() => _biometricEnabled = false);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            clientErrorMessage(
              error,
              fallback: enable
                  ? 'Unable to enable biometric quick login'
                  : 'Unable to disable biometric quick login',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) _updateState(() => _biometricBusy = false);
    }
  }

  Widget _selectedBody() {
    switch (selectedIndex) {
      case 0:
        return _marketBody();

      case 1:
        return MarketsPage(
          stocks: stocks,
          nifty50Price: nifty50Price,
          nifty50Change: nifty50Change,
          sensexPrice: sensexPrice,
          sensexChange: sensexChange,
          bankNiftyPrice: bankNiftyPrice,
          bankNiftyChange: bankNiftyChange,
          indexQuotes: indexQuotes,
          notificationCount: unreadNotificationCount,
          onNotifications: _openNotifications,
          onStockTap: _openStock,
          onRefresh: _refreshMarketData,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        );

      case 2:
        return TradingCenterPage(
          stocks: stocks,
          positions: positions,
          orders: orders,
          institutionalStocks: institutionalStocks,
          ipos: ipos,
          ipoApplications: ipoApplications,
          iposFailed: _iposFailed,
          ipoApplicationsFailed: _ipoApplicationsFailed,
          onRetryIpos: () async {
            await Future.wait([
              _loadDashboardSection(() async {
                try {
                  final remote = await ipoService.fetchOpenIpos();
                  ipos
                    ..clear()
                    ..addAll(remote);
                  _iposFailed = false;
                } catch (_) {
                  _iposFailed = true;
                  rethrow;
                }
              }),
              _loadDashboardSection(() async {
                try {
                  final remote = await ipoService.fetchMyApplications();
                  ipoApplications
                    ..clear()
                    ..addAll(remote);
                  _ipoApplicationsFailed = false;
                } catch (_) {
                  _ipoApplicationsFailed = true;
                  rethrow;
                }
              }),
            ]);
          },
          onTrade: _openStock,
          onApplyIpo: _applyIpo,
          onAlertsTap: _openNotifications,
          notificationCount: unreadNotificationCount,
          indexQuotes: indexQuotes,
          onViewMarkets: () => _onDestinationSelected(1),
          onOpenOrderTicket: _openStockForTrade,
          marketOpen: marketOpen,
          marketHours: marketHours,
          quotesConnected: marketConnected,
        );

      case 3:
        return _portfolioBody();

      case 4:
        return _accountBody();

      default:
        return _marketBody();
    }
  }

  String _balanceText(double value, {bool signed = false}) {
    if (_amountsHidden) return '******';
    if (!_accountSnapshotLoaded) return '--';
    return signed ? formatSignedPrice(value) : formatPrice(value);
  }

  Widget _accountDataStatus() => AccountDataStatus(
    hasData: _accountSnapshotLoaded,
    refreshing: _accountSnapshotRefreshing,
    failed: _accountSnapshotFailed,
    onRetry: () => unawaited(_refreshAccountSnapshot()),
  );

  Widget _companyShowcaseCard(CompanyShowcase company) {
    return AppCard(
      radius: AppRadius.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimarySoft,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: company.logoUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: AppRadius.borderSm,
                        child: Image.network(
                          company.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.business_rounded,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.business_rounded,
                        color: AppColors.brandPrimary,
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      company.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    AppText(
                      company.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (company.videoUrl?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => launchUrl(Uri.parse(company.videoUrl!)),
              borderRadius: AppRadius.borderSm,
              child: Container(
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: AppRadius.borderSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        color: AppColors.brandPrimary,
                        size: 28,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      AppText(
                        _appContent.text(
                          'home',
                          'company.video_cta',
                          fallback: 'Watch our company introduction',
                        ),
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppText(
            company.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(height: 1.45),
          ),
          if (company.websiteUrl?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(company.websiteUrl!)),
                child: AppText(
                  _appContent.text(
                    'home',
                    'company.website_cta',
                    fallback: 'Visit website',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openDepositSupport() {
    // APP Add Funds opens the in-app Deposit page (not the side Support button).
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const DepositPage()));
  }

  Future<void> _openWithdrawalRequest() async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WithdrawalPage(
          availableBalance: availableBalance,
          frozenBalance: frozenBalance,
          accountName: accountName,
          onFundsUpdated: (request, snapshot) {
            if (!mounted) return;
            _updateState(() {
              withdrawalRequests.removeWhere((item) => item.id == request.id);
              withdrawalRequests.insert(0, request);
              if (snapshot != null) {
                _applyAccountSnapshot(snapshot, positions: false);
              } else {
                buyingPower = math
                    .max(0, buyingPower - request.amount)
                    .toDouble();
                frozenBalance += request.amount;
              }
            });
          },
        ),
      ),
    );
  }
}
