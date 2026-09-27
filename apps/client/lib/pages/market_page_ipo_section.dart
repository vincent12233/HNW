part of 'market_page.dart';

extension _MarketHomeIpoSection on _MarketHomePageState {
  Future<void> _applyIpo(Ipo ipo) async {
    final applicationCount = ipoApplications
        .where((application) => application.ipoId == ipo.id)
        .length;

    if (applicationCount >= 5) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('Maximum of 5 applications allowed for this IPO'),
        ),
      );

      return;
    }

    try {
      await ipoService.apply(ipo.id);
      final remoteApplications = await ipoService.fetchMyApplications();

      if (!mounted) return;

      _updateState(() {
        ipoApplications
          ..clear()
          ..addAll(remoteApplications);
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            '${ipo.companyName} application ${applicationCount + 1} of 5 submitted',
          ),
        ),
      );
    } on IpoException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(error.message)));
    }
  }

  void _showPendingIpoAllocationIfNeeded() {
    if (!mounted || _ipoAllocationDialogOpen) {
      return;
    }

    IpoApplication? pendingApplication;

    for (final application in ipoApplications) {
      if (application.hasAllocation &&
          !_shownIpoAllotments.contains(application.id)) {
        pendingApplication = application;
        break;
      }
    }

    if (pendingApplication == null) {
      return;
    }

    _showIpoAllocationDialog(pendingApplication);
  }

  Future<void> _showIpoAllocationDialog(IpoApplication application) async {
    if (!mounted || _ipoAllocationDialogOpen) {
      return;
    }

    if (!application.hasAllocation) {
      return;
    }

    _ipoAllocationDialogOpen = true;
    _shownIpoAllotments.add(application.id);
    final noticeStore = IpoNoticeStore();
    bool previouslyConfirmed = false;
    try {
      previouslyConfirmed = await noticeStore.isConfirmed(application.id);
    } catch (_) {
      // Storage failure must not prevent the customer seeing an allotment.
    }
    if (!mounted || previouslyConfirmed) {
      _ipoAllocationDialogOpen = false;
      if (mounted) _showPendingIpoAllocationIfNeeded();
      return;
    }
    final needsFunds = application.remainingAmount > 0;

    final totalSubscriptionAmount =
        application.allocatedQuantity * application.subscriptionPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE59A), Color(0xFFFFBF36)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 68,
                  color: Color(0xFFB77700),
                ),
              ),
              const SizedBox(height: 20),
              const AppText(
                'Congratulations!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFB77700),
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 10),
              const AppText(
                'Your IPO application has been successfully allotted.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  application.companyName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                AppText(
                  application.symbol,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: needsFunds
                        ? const Color(0xFFFFF1F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AppText(
                    needsFunds
                        ? 'You have received an IPO allotment. '
                              'Please add the required funds to complete '
                              'your subscription. No further action is needed after funds arrive.'
                        : 'Your subscription is complete. Your allocated shares have been added to your holdings.',
                    style: TextStyle(
                      height: 1.4,
                      color: needsFunds
                          ? const Color(0xFFB42318)
                          : const Color(0xFF047857),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ipoDialogValue(
                  'Allocated Quantity',
                  '${application.allocatedQuantity} Shares',
                ),
                const Divider(height: 24),
                _ipoDialogValue(
                  'Subscription Price',
                  formatPrice(application.subscriptionPrice),
                ),
                const Divider(height: 24),
                _ipoDialogValue(
                  'Total Subscription Amount',
                  formatPrice(totalSubscriptionAmount),
                ),
                if (needsFunds) ...[
                  const Divider(height: 24),
                  _ipoDialogValue(
                    'Additional Funds Required',
                    formatPrice(application.remainingAmount),
                    valueColor: AppConfig.lossColor,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const AppText('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await noticeStore.confirm(application.id);
      } catch (_) {
        // Session-level deduplication still applies if persistence is unavailable.
      }
    }
    _ipoAllocationDialogOpen = false;
    if (mounted) _showPendingIpoAllocationIfNeeded();
  }

  Widget _ipoDialogValue(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppText(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        AppText(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
