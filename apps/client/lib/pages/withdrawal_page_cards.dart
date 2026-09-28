part of 'withdrawal_page.dart';

extension _WithdrawalPageCards on _WithdrawalPageState {
  Widget _staleDataNotice() {
    final updatedAt = _loadState.updatedAt;
    final timestamp = updatedAt == null
        ? 'an earlier update'
        : '${updatedAt.hour.toString().padLeft(2, '0')}:${updatedAt.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        backgroundColor: AppColors.warningSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppText(
                'Showing previously loaded data from $timestamp. '
                '${_loadState.message ?? 'Refresh when your connection returns.'}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return AppCard(
      backgroundColor: AppColors.brandDark,
      bordered: false,
      shadow: AppCardShadow.medium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Available Funds',
            style: AppTypography.caption.copyWith(
              color: AppColors.textInverse.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppText(
            formatPrice(_available),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.display.copyWith(
              color: AppColors.textInverse,
              fontFeatures: AppTypography.tabularFeatures,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppText(
            'Total frozen: ${formatPrice(_frozen)}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textInverse.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gateCard({
    required String title,
    required String message,
    required String action,
    required VoidCallback onPressed,
  }) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title, style: AppTypography.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          AppText(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(label: action, onPressed: onPressed),
        ],
      ),
    );
  }

  Widget _formCard() {
    final bank = _selectedBank;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,13}([.]\d{0,2})?$'),
              ),
            ],
            decoration: InputDecoration(
              labelText: tr('Withdrawal Amount'),
              prefixText: '₹ ',
              errorText: _formError,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const AppText(
            'Minimum withdrawal: ₹100',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(labelText: tr('Withdrawal PIN')),
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: bank?['id']?.toString(),
            decoration: InputDecoration(labelText: tr('Bank account')),
            items: _banks.map((item) {
              final number = item['accountNumber']?.toString() ?? '';
              final suffix = number.length > 4
                  ? number.substring(number.length - 4)
                  : number;
              return DropdownMenuItem(
                value: item['id']?.toString(),
                child: AppText(
                  '${item['bankName']} ••••$suffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (id) => _setState(() {
              _selectedBank = _banks.firstWhere(
                (item) => item['id']?.toString() == id,
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          _kv(
            'Account Holder',
            bank?['accountHolder']?.toString() ?? widget.accountName,
          ),
          _kv(
            'Bank Account',
            bank?['accountNumber']?.toString() ?? 'Unavailable',
          ),
          _kv('IFSC', bank?['ifscCode']?.toString() ?? 'Unavailable'),
          _kv('Bank Status', bank?['status']?.toString() ?? 'Added'),
          const SizedBox(height: AppSpacing.lg),
          AppText(
            'Submit here in the app. Finance reviews your request. '
            'The amount is frozen right away. Approval deducts cash; '
            'rejection releases the freeze.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppPrimaryButton(
            label: 'Submit Request',
            loading: _submitting,
            onPressed: _submitting || _loadState.isLoading ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _historyCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppText(
                  'Withdrawal Records',
                  style: AppTypography.titleMedium,
                ),
              ),
              IconButton(
                tooltip: tr('Refresh withdrawal history'),
                onPressed: _loadState.isLoading
                    ? null
                    : () => unawaited(_load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (_loadState.message != null && _history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppText(_loadState.message!),
            ),
          if (_history.isEmpty && _loadState.message == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: AppText('No withdrawal records yet.'),
            )
          else if (_history.isEmpty && _loadState.message != null)
            AppErrorView(
              compact: true,
              title: 'Unable to load withdrawals',
              message: _loadState.message,
              onRetry: () => unawaited(_load()),
            )
          else
            for (final request in _history) _historyTile(request),
        ],
      ),
    );
  }

  Widget _historyTile(WithdrawalRequest request) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => unawaited(
          showRecordDetailSheet(
            context,
            title: request.orderNo ?? request.id,
            status: AppStatusChip(
              label: request.statusLabel,
              variant: chipVariantForStatus(request.status.name),
              compact: true,
            ),
            rows: [
              ('Amount', formatPrice(request.amount)),
              ('Status', request.statusLabel),
              ('Funds', request.fundsStatusLabel),
              ('Requested', formatAppDateTime(request.createdAt)),
              (
                'Bank',
                request.bankName.isEmpty ? 'Unavailable' : request.bankName,
              ),
              (
                'Account',
                request.maskedAccountNumber.isEmpty
                    ? 'Unavailable'
                    : request.maskedAccountNumber,
              ),
              (
                'IFSC',
                request.ifscCode.isEmpty ? 'Unavailable' : request.ifscCode,
              ),
            ],
          ),
        ),
        title: AppText(
          request.orderNo ?? request.id,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(formatPrice(request.amount)),
            AppText(
              '${request.statusLabel} · ${formatAppDateTime(request.createdAt)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 96),
          child: AppStatusChip(
            label: request.statusLabel,
            variant: chipVariantForStatus(request.status.name),
            compact: true,
          ),
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: AppText(label, style: AppTypography.caption)),
          Flexible(
            child: AppText(
              value.isEmpty ? 'Unavailable' : value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
