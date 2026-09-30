part of 'kyc_upload_page.dart';

extension _KycUploadOverviewSection on _KycUploadPageState {
  List<Widget> _overviewChildren() {
    final rejected = existingStatus == 'REJECTED';
    final pending = existingStatus == 'PENDING';
    final approved = existingStatus == 'APPROVED';
    final progressCount = _reviewLocked ? 6 : completedSteps;
    final steps = _overviewSteps;

    return [
      const AuthBrandHeader(showSlogan: false),
      const SizedBox(height: AuthLayout.titleGap),
      const AppText('KYC Verification', style: AuthLayout.title),
      const SizedBox(height: AuthLayout.titleGap),
      const AppText(
        'Use your PAN or Aadhaar, selfie, signature, and bank details.',
        style: AuthLayout.subtitle,
      ),
      if (!_reviewLocked) ...[
        const SizedBox(height: AuthLayout.fieldGap),
        const AppText(
          'Choose Identity Document',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: AuthLayout.bodySize,
            letterSpacing: 0,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 360;
            final pan = _documentOption(
              'PAN',
              'PAN Card',
              'Front photo required',
              Icons.badge_outlined,
            );
            final aadhaar = _documentOption(
              'AADHAAR',
              'Aadhaar Card',
              'Front & back required',
              Icons.fingerprint,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [pan, const SizedBox(height: 12), aadhaar],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: pan),
                const SizedBox(width: 12),
                Expanded(child: aadhaar),
              ],
            );
          },
        ),
      ],
      const SizedBox(height: AuthLayout.fieldGap),
      if (pending)
        const VerificationBanner(
          tone: KycBannerTone.warning,
          title: 'Verification in Progress',
          subtitle: 'Your documents are waiting for business review.',
        )
      else if (approved)
        const VerificationBanner(
          tone: KycBannerTone.success,
          icon: Icons.verified,
          title: 'Verification Complete',
          subtitle: 'Your account has been verified.',
        )
      else if (rejected)
        VerificationBanner(
          tone: KycBannerTone.danger,
          icon: Icons.error_outline,
          title: 'Needs resubmission',
          subtitle:
              reviewNote ?? 'Please update your documents and submit again.',
        )
      else
        const VerificationBanner(
          tone: KycBannerTone.info,
          title: 'Manual review required',
          subtitle:
              'Complete each step below. Uploading files does not mean KYC is approved.',
        ),
      if (_reviewLocked) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _loadStatus,
          icon: const Icon(Icons.refresh),
          label: const AppText('Refresh Status'),
        ),
      ],
      const SizedBox(height: AuthLayout.fieldGap),
      KycProgressHeader(completed: progressCount),
      const SizedBox(height: AuthLayout.fieldGap),
      const AppText(
        'Verification Steps',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: AuthLayout.bodySize,
          letterSpacing: 0,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      for (var index = 0; index < steps.length; index++)
        KycStepTile(
          key: ValueKey('kyc-step-$index'),
          icon: steps[index].icon,
          title: steps[index].title,
          subtitle: steps[index].subtitle,
          state: _stepState(index, steps[index].complete),
          onTap: _reviewLocked
              ? null
              : steps[index].title == 'Personal Details'
              ? _personalDetails
              : null,
        ),
    ];
  }

  Widget _footer() {
    final label = _reviewLocked
        ? 'Back to Login'
        : step == 5
        ? 'Submit KYC for Review'
        : step == 0
        ? 'Continue Verification'
        : 'Continue';
    VoidCallback? onPressed;
    if (isSubmitting) {
      onPressed = null;
    } else if (_reviewLocked) {
      onPressed = () => Navigator.popUntil(context, (route) => route.isFirst);
    } else if (step == 5) {
      onPressed = _submit;
    } else {
      onPressed = () {
        if (step == 0 && fullName.isEmpty) {
          _personalDetails();
          return;
        }
        if (step == 1 && !documentsReady) {
          _setState(
            () => errorText = documentType == 'AADHAAR'
                ? 'Add both the front and back of Aadhaar'
                : 'Add your PAN document',
          );
          return;
        }
        if (step == 2 && selfieFile == null) {
          _setState(() => errorText = 'Add your selfie to continue');
          return;
        }
        if (step == 3 && signatureFile == null) {
          _setState(() => errorText = 'Save your signature to continue');
          return;
        }
        _goTo(step + 1);
      };
    }

    return KycFlowFooter(
      label: label,
      busy: isSubmitting,
      errorText: errorText,
      securityNotice: true,
      onPressed: onPressed,
    );
  }

  Widget _documentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = documentType == value;
    return InkWell(
      borderRadius: AppRadius.borderSm,
      onTap: () => _setState(() {
        if (documentType != value) {
          selectedFile = null;
          selectedBackFile = null;
        }
        documentType = value;
        errorText = null;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimarySoft
              : AuthLayout.pageBackground,
          borderRadius: AppRadius.borderSm,
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (value == 'AADHAAR')
                  const AadhaarMark()
                else
                  Icon(icon, color: AppColors.brandPrimary),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 17,
                  color: selected
                      ? AppColors.brandPrimary
                      : AppColors.textTertiary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppText(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 5),
            AppText(
              subtitle,
              style: const TextStyle(
                fontSize: AuthLayout.helperSize,
                height: 1.35,
                letterSpacing: 0,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
