part of 'kyc_upload_page.dart';

extension _KycUploadStepsSection on _KycUploadPageState {
  List<Widget> _documentStep() {
    final pan = documentType == 'PAN';
    return [
      KycStepIntro(
        current: 2,
        total: 6,
        title: pan ? 'Upload PAN Card' : 'Aadhaar Verification',
        subtitle: pan
            ? 'Upload a clear photo of the front of your PAN. Files are stored for manual review.'
            : 'Upload clear photos of the front and back of your Aadhaar. Files are stored for manual review.',
      ),
      const SizedBox(height: AuthLayout.fieldGap),
      AppText(
        pan ? 'You have selected PAN Card' : 'You have selected Aadhaar Card',
        style: const TextStyle(
          fontSize: AuthLayout.bodySize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      const AppText(
        'PDF, JPG, PNG, WEBP, HEIC or HEIF · Maximum 15 MB',
        style: TextStyle(
          fontSize: AuthLayout.helperSize,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AuthLayout.fieldGap),
      _uploadPanel(back: false),
      if (!pan) ...[
        const SizedBox(height: 20),
        _uploadPanel(back: true),
      ],
    ];
  }

  List<Widget> _selfieStep() => [
    const KycStepIntro(
      current: 3,
      total: 6,
      title: 'Take a Clear Selfie',
      subtitle:
          'Take a selfie in good lighting. Keep your face fully visible. This photo is stored for manual review.',
    ),
    const SizedBox(height: AuthLayout.fieldGap),
    KycSelfieFrame(bytes: selfieFile?.bytes),
    const SizedBox(height: 16),
    KycStatusSwitch(
      switchKey: selfieFile == null ? 'empty' : 'captured',
      child: selfieFile == null
          ? const SizedBox.shrink()
          : const Column(
              children: [
                AppText(
                  'Selfie captured',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    color: AppColors.brandPrimary,
                  ),
                ),
                SizedBox(height: 4),
                AppText(
                  'Waiting for manual review',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AuthLayout.helperSize,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
    ),
    const AppText(
      'Keep your face fully visible. Remove glasses, hats and masks. Use even lighting and avoid blur.',
      style: TextStyle(
        fontSize: AuthLayout.helperSize,
        height: 1.5,
        letterSpacing: 0,
        color: AppColors.textSecondary,
      ),
    ),
    const SizedBox(height: 20),
    AuthSubmitButton(
      label: selfieFile == null ? 'Capture Selfie' : 'Retake',
      icon: selfieFile == null ? Icons.camera_alt : Icons.refresh,
      onPressed: _captureSelfie,
    ),
    const SizedBox(height: 8),
    const AppText(
      'Live camera capture only · Submitted for manual review',
      style: TextStyle(
        fontSize: AuthLayout.helperSize,
        color: AppColors.textSecondary,
      ),
    ),
  ];

  List<Widget> _signatureStep() => [
    const KycStepIntro(
      current: 4,
      total: 6,
      title: 'Provide Your Signature',
      subtitle: 'Sign below using your finger or a stylus.',
    ),
    const SizedBox(height: AuthLayout.fieldGap),
    KycStatusSwitch(
      switchKey: signatureFile == null ? 'pad' : 'saved',
      child: signatureFile == null
          ? KycSignaturePad(
              onSaved: (bytes) => _setState(() {
                signatureFile = PickedBytesFile(
                  name: 'signature.png',
                  bytes: bytes,
                );
                errorText = null;
              }),
              onChanged: () {
                if (signatureFile != null) {
                  _setState(() => signatureFile = null);
                }
              },
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Image.memory(
                    signatureFile!.bytes,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: AppMotion.iconInline,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: AppText(
                        'Signature saved',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const AppText(
                  'Waiting for manual review',
                  style: TextStyle(
                    fontSize: AuthLayout.helperSize,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                AuthOutlinedButton(
                  label: 'Retake Signature',
                  icon: Icons.refresh,
                  onPressed: () => _setState(() => signatureFile = null),
                ),
              ],
            ),
    ),
  ];

  List<Widget> _reviewStep() {
    final missing = <String>[
      if (fullName.isEmpty) 'Personal details',
      if (!documentsReady)
        documentType == 'AADHAAR'
            ? 'Aadhaar front and back'
            : 'PAN document',
      if (selfieFile == null) 'Selfie',
      if (signatureFile == null) 'Signature',
      if (bankDetails == null) 'Bank details',
    ];
    return [
      const KycStepIntro(
        current: 6,
        total: 6,
        title: 'Review Documents',
        subtitle:
            'Check each step before submitting. Uploading files does not mean KYC is approved.',
      ),
      const SizedBox(height: AuthLayout.fieldGap),
      const VerificationBanner(
        tone: KycBannerTone.info,
        title: 'Waiting for manual review',
        subtitle:
            'After you submit, a reviewer will check your documents. There is no instant verification.',
      ),
      const SizedBox(height: AuthLayout.fieldGap),
      if (missing.isNotEmpty) ...[
        VerificationBanner(
          tone: KycBannerTone.danger,
          icon: Icons.error_outline,
          title: 'Missing information',
          subtitle: missing.join(', '),
        ),
        const SizedBox(height: AuthLayout.fieldGap),
      ],
      _reviewRow(
        'Personal Details',
        fullName.isEmpty ? 'Not added' : fullName,
        complete: fullName.isNotEmpty,
        onEdit: _personalDetails,
      ),
      _reviewRow(
        'Upload documents',
        documentsReady
            ? (documentType == 'PAN'
                  ? selectedFile?.name ?? 'PAN Card'
                  : 'Aadhaar front and back selected')
            : 'Not added',
        complete: documentsReady,
        onEdit: () => _goTo(1),
      ),
      _reviewRow(
        'Selfie',
        selfieFile?.name ?? 'Not added',
        complete: selfieFile != null,
        onEdit: () => _goTo(2),
      ),
      _reviewRow(
        'Signature',
        signatureFile?.name ?? 'Not added',
        complete: signatureFile != null,
        onEdit: () => _goTo(3),
      ),
      _reviewRow(
        'Bank Details',
        bankDetails == null
            ? 'Not added'
            : '${bankDetails!['bankName']}\n${bankDetails!['accountHolder']}\n${_maskedAccount(bankDetails!['accountNumber'] ?? '')}',
        complete: bankDetails != null,
        onEdit: _bankDetails,
      ),
      const SizedBox(height: 16),
      const AppText(
        'Check that all details are readable before submitting. Uploading documents does not mean your KYC has been approved.',
        style: TextStyle(
          color: AppColors.textSecondary,
          height: 1.6,
          letterSpacing: 0,
        ),
      ),
    ];
  }

}


