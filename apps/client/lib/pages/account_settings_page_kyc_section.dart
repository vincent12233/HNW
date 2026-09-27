part of 'account_settings_page.dart';

extension _AccountSettingsKycSection on _AccountSettingsPageState {
  Widget _kyc() {
    final k = data is Map
        ? Map<String, dynamic>.from(data as Map)
        : <String, dynamic>{};
    final status = k['status']?.toString() ?? 'NOT_SUBMITTED';
    final label = profileKycLabel(status);
    return ListView(
      padding: AppSpacing.page,
      children: [
        AppCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status == 'APPROVED'
                    ? Icons.badge_outlined
                    : status == 'REJECTED'
                    ? Icons.error_outline
                    : Icons.hourglass_top,
                size: 52,
                color: profileKycColor(status) == AppColors.textSecondary
                    ? AppConfig.neutralColor
                    : profileKycColor(status),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppText(label, style: AppTypography.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              const AppText(
                'Review is completed by the operations team. This screen does not confirm identity or bank checks automatically.',
                textAlign: TextAlign.center,
              ),
              if (status != 'APPROVED') ...[
                const SizedBox(height: AppSpacing.lg),
                AppPrimaryButton(
                  label: status == 'REJECTED'
                      ? 'Resubmit documents'
                      : status == 'NOT_SUBMITTED'
                      ? 'Start verification'
                      : 'Update documents',
                  icon: Icons.upload_file_rounded,
                  onPressed: _startKyc,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AppText(
                k['reviewNote']?.toString().trim().isNotEmpty == true
                    ? k['reviewNote'].toString()
                    : 'Your latest KYC verification status is shown here.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}