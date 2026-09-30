part of 'account_settings_page.dart';

extension _AccountSettingsBanksSection on _AccountSettingsPageState {
  Widget _banks() {
    final rows = data is List
        ? (data as List)
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
        : <Map<String, dynamic>>[];
    return ListView(
      padding: AppSpacing.page,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          AppErrorView(
            title: error!,
            onRetry: loading || _deletingBank ? null : load,
            compact: true,
          ),
        const AppText(
          'Saved bank details are protected and used to support secure withdrawals.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (rows.isEmpty)
          const AppEmptyState(
            compact: true,
            title: 'No bank account linked',
            message: 'Add a bank account to enable secure withdrawals.',
            icon: Icons.account_balance_outlined,
          )
        else
          for (final bank in rows) _bankCard(bank),
        const SizedBox(height: AppSpacing.lg),
        AppPrimaryButton(
          label: 'Add bank account',
          icon: Icons.add,
          onPressed: _deletingBank || loading ? null : _addBank,
        ),
      ],
    );
  }

  Widget _bankCard(Map<String, dynamic> bank) {
    final id = bank['id']?.toString() ?? '';
    final revealed = _revealedBanks.contains(id);
    final name = displayOrUnavailable(bank['bankName']);
    final holder = displayOrUnavailable(bank['accountHolder']);
    final status = bank['status']?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(name, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            AppText(
              maskBankAccountNumber(
                bank['accountNumber']?.toString() ?? '',
                revealed: revealed,
              ),
            ),
            AppText(
              'IFSC ${maskIfscCode(bank['ifscCode']?.toString() ?? '', revealed: revealed)}',
            ),
            AppText('Holder $holder'),
            AppText(
              status.isEmpty ? 'Bank account details saved securely' : status,
              style: AppTypography.caption,
            ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: revealed
                      ? 'Hide account number'
                      : 'Show account number',
                  constraints: const BoxConstraints(
                    minWidth: AppMotion.tapTarget,
                    minHeight: AppMotion.tapTarget,
                  ),
                  onPressed: id.isEmpty
                      ? null
                      : () => _setState(() {
                          if (revealed) {
                            _revealedBanks.remove(id);
                          } else {
                            _revealedBanks.add(id);
                          }
                        }),
                  icon: Icon(
                    revealed ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
                IconButton(
                  tooltip: tr('Remove bank account'),
                  constraints: const BoxConstraints(
                    minWidth: AppMotion.tapTarget,
                    minHeight: AppMotion.tapTarget,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed:
                      _deletingBank || loading || error != null || id.isEmpty
                      ? null
                      : () => _deleteBank(bank),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteBank(Map<String, dynamic> bank) async {
    final id = bank['id']?.toString() ?? '';
    if (id.isEmpty || _deletingBank || loading || error != null) return;
    _setState(() => _deletingBank = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const AppText('Remove bank account?'),
          content: AppText(
            'You will no longer be able to withdraw to ${bank['bankName'] ?? 'this account'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const AppText('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const AppText('Remove'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      try {
        await service.deleteBank(id);
        if (mounted) await load();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: AppText(clientErrorMessage(error))));
        }
      }
    } finally {
      if (mounted) _setState(() => _deletingBank = false);
    }
  }

  Future<void> _addBank() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BankDetailsPage()),
    );
    if (saved == true && mounted) await load();
  }
}
