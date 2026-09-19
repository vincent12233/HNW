import '../l10n/app_language.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_bytes_file.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import '../widgets/kyc_signature_pad.dart';
import '../widgets/aadhaar_mark.dart';
import '../utils/client_error_message.dart';
import '../widgets/onboarding_widgets.dart';
import 'bank_details_page.dart';
import 'selfie_camera_page.dart';

@visibleForTesting
class KycUploadDebugHarness {
  const KycUploadDebugHarness({
    this.step,
    this.documentType,
    this.fullName,
    this.selectedFile,
    this.selectedBackFile,
    this.selfieFile,
    this.signatureFile,
    this.bankDetails,
    this.existingStatus,
    this.reviewNote,
    this.pickDocument,
    this.pickSelfie,
  });

  final int? step;
  final String? documentType;
  final String? fullName;
  final PickedBytesFile? selectedFile;
  final PickedBytesFile? selectedBackFile;
  final PickedBytesFile? selfieFile;
  final PickedBytesFile? signatureFile;
  final Map<String, String>? bankDetails;
  final String? existingStatus;
  final String? reviewNote;
  final Future<PickedBytesFile?> Function({required bool back})? pickDocument;
  final Future<PickedBytesFile?> Function({required ImageSource source})?
  pickSelfie;
}

class KycUploadPage extends StatefulWidget {
  const KycUploadPage({super.key, this.accessToken, this.debugHarness});

  final String? accessToken;
  @visibleForTesting
  final KycUploadDebugHarness? debugHarness;

  @override
  State<KycUploadPage> createState() => _KycUploadPageState();
}

class _KycUploadPageState extends State<KycUploadPage> {
  final authService = AuthService();
  final _scrollController = ScrollController();
  Timer? _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(int nextStep) {
    if (nextStep == 4) {
      _bankDetails();
      return;
    }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      step = nextStep;
      errorText = null;
    });
  }

  String documentType = 'PAN';
  PickedBytesFile? selectedFile;
  PickedBytesFile? selectedBackFile;
  bool isSubmitting = false;
  String? errorText;
  int step = 0;
  PickedBytesFile? selfieFile;
  PickedBytesFile? signatureFile;
  Map<String, String>? bankDetails;
  String fullName = '';
  String? existingStatus, reviewNote;

  @override
  void initState() {
    super.initState();
    final harness = widget.debugHarness;
    if (harness != null) {
      step = harness.step ?? step;
      documentType = harness.documentType ?? documentType;
      fullName = harness.fullName ?? fullName;
      selectedFile = harness.selectedFile;
      selectedBackFile = harness.selectedBackFile;
      selfieFile = harness.selfieFile;
      signatureFile = harness.signatureFile;
      bankDetails = harness.bankDetails;
      existingStatus = harness.existingStatus;
      reviewNote = harness.reviewNote;
    }
    if (harness?.existingStatus == null) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final completer = Completer<Map<String, dynamic>>();
    _statusTimer = Timer(const Duration(seconds: 8), () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('KYC status request timed out'),
        );
      }
    });
    authService
        .kycDetails(accessToken: widget.accessToken)
        .then((status) {
          if (!completer.isCompleted) completer.complete(status);
        })
        .catchError((error, stack) {
          if (!completer.isCompleted) completer.completeError(error, stack);
        });
    try {
      final status = await completer.future;
      if (mounted) {
        setState(() {
          existingStatus = status['status']?.toString();
          reviewNote = status['reviewNote']?.toString();
        });
      }
    } catch (e) {
      if (mounted) setState(() => errorText = clientErrorMessage(e));
    } finally {
      _statusTimer?.cancel();
      _statusTimer = null;
    }
  }

  bool get documentsReady =>
      selectedFile != null &&
      (documentType != 'AADHAAR' || selectedBackFile != null);

  int get completedSteps => [
    fullName.isNotEmpty,
    documentsReady,
    selfieFile != null,
    signatureFile != null,
    bankDetails != null,
    step == 5,
  ].where((value) => value).length;

  bool get _reviewLocked =>
      existingStatus == 'PENDING' || existingStatus == 'APPROVED';

  List<({IconData icon, String title, String subtitle, bool complete})>
  get _overviewSteps => [
    (
      icon: Icons.badge_outlined,
      title: 'Personal Details',
      subtitle: fullName.isEmpty ? 'Basic identity information' : fullName,
      complete: _reviewLocked || fullName.isNotEmpty,
    ),
    (
      icon: Icons.photo_camera_outlined,
      title: 'Upload documents',
      subtitle: 'Take a photo or choose a file',
      complete: _reviewLocked || documentsReady,
    ),
    (
      icon: Icons.face_outlined,
      title: 'Selfie',
      subtitle: 'A clear photo for manual review',
      complete: _reviewLocked || selfieFile != null,
    ),
    (
      icon: Icons.draw_outlined,
      title: 'Signature',
      subtitle: 'Sign using your finger or stylus',
      complete: _reviewLocked || signatureFile != null,
    ),
    (
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      subtitle: 'Add your bank account information',
      complete: _reviewLocked || bankDetails != null,
    ),
    (
      icon: Icons.fact_check_outlined,
      title: 'Review & submit',
      subtitle: 'Your documents will be reviewed',
      complete: _reviewLocked || step == 5,
    ),
  ];

  KycStepUiState _stepState(int index, bool complete) {
    if (complete) return KycStepUiState.completed;
    final firstOpen = _overviewSteps.indexWhere((item) => !item.complete);
    if (index == firstOpen) return KycStepUiState.inProgress;
    return KycStepUiState.notStarted;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final maxWidth = AuthLayout.formMaxWidth(media.size.width);
    final horizontal = AuthLayout.horizontalPadding(media.size.width);

    return PopScope(
      canPop: !isSubmitting && step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isSubmitting && step > 0) _goTo(step - 1);
      },
      child: Scaffold(
        backgroundColor: AuthLayout.pageBackground,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: AuthLayout.pageBackground,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: BackButton(
            onPressed: isSubmitting
                ? null
                : () {
                    if (step > 0) {
                      _goTo(step - 1);
                    } else {
                      Navigator.maybePop(context);
                    }
                  },
          ),
          title: AppText(
            [
              'KYC Verification',
              documentType == 'PAN' ? 'Upload PAN Card' : 'Aadhaar Verification',
              'Selfie Verification',
              'Signature',
              'Bank Details',
              'Review Documents',
            ][step],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: SizedBox(
                      width: double.infinity,
                      child: SingleChildScrollView(
                        key: const ValueKey('kyc-overview-scroll'),
                        controller: _scrollController,
                        clipBehavior: Clip.hardEdge,
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          AuthLayout.pagePaddingTop,
                          horizontal,
                          AuthLayout.fieldGap,
                        ),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                  if (step == 0 || _reviewLocked) ..._overviewChildren(),
                  if (!_reviewLocked && step == 1) ..._documentStep(),
                  if (!_reviewLocked && step == 2) ..._selfieStep(),
                  if (!_reviewLocked && step == 3) ..._signatureStep(),
                  if (!_reviewLocked && step == 5) ..._reviewStep(),
                          const SizedBox(height: 24),
                    ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _overviewChildren() {
    final rejected = existingStatus == 'REJECTED';
    final pending = existingStatus == 'PENDING';
    final approved = existingStatus == 'APPROVED';
    final progressCount = _reviewLocked ? 6 : completedSteps;
    final steps = _overviewSteps;

    return [
      const AuthBrandHeader(showSlogan: false),
      const SizedBox(height: AuthLayout.titleGap),
      const Text('KYC Verification', style: AuthLayout.title),
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
              reviewNote ??
              'Please update your documents and submit again.',
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
          setState(
            () => errorText = documentType == 'AADHAAR'
                ? 'Add both the front and back of Aadhaar'
                : 'Add your PAN document',
          );
          return;
        }
        if (step == 2 && selfieFile == null) {
          setState(() => errorText = 'Add your selfie to continue');
          return;
        }
        if (step == 3 && signatureFile == null) {
          setState(() => errorText = 'Save your signature to continue');
          return;
        }
        _goTo(step + 1);
      };
    }

    return KycFlowFooter(
      label: label,
      busy: isSubmitting,
      errorText: errorText,
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
      onTap: () => setState(() {
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
          color: selected ? AppColors.brandPrimarySoft : AuthLayout.pageBackground,
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
    if (selfieFile != null) ...[
      const AppText(
        'Selfie captured',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.brandPrimary,
        ),
      ),
      const SizedBox(height: 4),
      const AppText(
        'Waiting for manual review',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AuthLayout.helperSize,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 16),
    ],
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
      onPressed: () => _pickSelfie(ImageSource.camera),
    ),
    const SizedBox(height: 8),
    AuthOutlinedButton(
      label: 'Choose from Gallery',
      icon: Icons.photo_outlined,
      onPressed: () => _pickSelfie(ImageSource.gallery),
    ),
    const SizedBox(height: 8),
    const AppText(
      'Maximum 2 MB · Submitted for manual review',
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
    if (signatureFile == null)
      KycSignaturePad(
        onSaved: (bytes) => setState(() {
          signatureFile = PickedBytesFile(
            name: 'signature.png',
            bytes: bytes,
          );
          errorText = null;
        }),
        onChanged: () {
          if (signatureFile != null) {
            setState(() => signatureFile = null);
          }
        },
      )
    else ...[
      SizedBox(
        height: 180,
        width: double.infinity,
        child: Image.memory(
          signatureFile!.bytes,
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(height: 12),
      const AppText(
        'Signature saved',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
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
        onPressed: () => setState(() => signatureFile = null),
      ),
    ],
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

  Widget _reviewRow(
    String title,
    String subtitle, {
    required bool complete,
    required VoidCallback onEdit,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      complete ? Icons.check_circle : Icons.radio_button_unchecked,
      color: complete ? AppColors.success : AppColors.textTertiary,
    ),
    title: AppText(title),
    subtitle: AppText(subtitle),
    trailing: TextButton(
      onPressed: isSubmitting ? null : onEdit,
      child: const AppText('Edit'),
    ),
  );

  String _maskedAccount(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= 4) return '••••';
    return '•••• ${trimmed.substring(trimmed.length - 4)}';
  }

  Widget _uploadPanel({required bool back}) {
    final file = back ? selectedBackFile : selectedFile;
    final label = documentType == 'PAN'
        ? 'PAN Card Front'
        : back
        ? 'Aadhaar Back'
        : 'Aadhaar Front';
    return KycLocalFileCard(
      key: ValueKey(back ? 'kyc-document-back' : 'kyc-document-front'),
      title: '$label (Required)',
      hint: 'Keep all corners visible and avoid glare.',
      emptyLabel: 'Add $label',
      captureLabel: 'Capture ${back ? 'Back' : 'Front'}',
      file: file,
      busy: isSubmitting,
      onCapture: () => _takePhoto(back: back),
      onChoose: () => _pickFile(back: back),
      onReplace: () => _pickFile(back: back),
      onRemove: () => _confirmRemove(back: back),
    );
  }

  Future<void> _confirmRemove({required bool back}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Remove this file?'),
        content: const AppText(
          'This only clears the file selected on this device. It does not delete anything already submitted for review.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const AppText('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        if (back) {
          selectedBackFile = null;
        } else {
          selectedFile = null;
        }
        errorText = null;
      });
    }
  }

  Future<void> _pickSelfie(ImageSource source) async {
    try {
      final debugPick = widget.debugHarness?.pickSelfie;
      if (debugPick != null) {
        final file = await debugPick(source: source);
        if (!mounted || file == null) return;
        if (file.bytes.isEmpty || file.size > 2 * 1024 * 1024) {
          setState(() => errorText = 'Choose an image no larger than 2 MB');
          return;
        }
        final extension = file.extension ?? _imageExtension(file.bytes);
        if (extension == null ||
            !const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          setState(() => errorText = 'Choose a JPG, PNG or WebP image');
          return;
        }
        setState(() {
          selfieFile = file;
          errorText = null;
        });
        return;
      }
      if (source == ImageSource.camera) {
        final bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const SelfieCameraPage()),
        );
        if (bytes != null && mounted) {
          setState(() {
            selfieFile = PickedBytesFile(name: 'selfie.png', bytes: bytes);
            errorText = null;
          });
        }
        return;
      }
      final photo = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) {
        setState(() => errorText = 'Choose an image no larger than 2 MB');
        return;
      }
      final extension = _imageExtension(bytes);
      if (extension == null) {
        setState(() => errorText = 'Choose a JPG, PNG or WebP image');
        return;
      }
      setState(() {
        selfieFile = PickedBytesFile(name: 'selfie.$extension', bytes: bytes);
        errorText = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => errorText =
              'Unable to open the camera or gallery. Check permission and try again.',
        );
      }
    }
  }

  String? _imageExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
        String.fromCharCodes(bytes.skip(8).take(4)) == 'WEBP') {
      return 'webp';
    }
    return null;
  }

  Future<void> _pickFile({bool back = false}) async {
    try {
      await _readPickedFile(back: back);
    } catch (_) {
      if (mounted) {
        setState(() => errorText = 'Unable to open files. Please try again.');
      }
    }
  }

  Future<void> _readPickedFile({bool back = false}) async {
    final PickedBytesFile? file;
    final debugPick = widget.debugHarness?.pickDocument;
    if (debugPick != null) {
      file = await debugPick(back: back);
    } else {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      );
      if (!mounted || picked == null) {
        return;
      }
      file = PickedBytesFile(name: picked.name, bytes: await picked.readAsBytes());
    }

    if (!mounted || file == null) {
      return;
    }
    if (!_validateFile(file)) return;
    final chosen = file;
    setState(() {
      if (back) {
        selectedBackFile = chosen;
      } else {
        selectedFile = chosen;
      }
      errorText = null;
    });
  }

  Future<void> _takePhoto({bool back = false}) async {
    try {
      await _captureDocument(back: back);
    } catch (_) {
      if (mounted) {
        setState(
          () => errorText =
              'Unable to open the camera. Check camera permission or choose a file.',
        );
      }
    }
  }

  Future<void> _captureDocument({bool back = false}) async {
    if (widget.debugHarness?.pickDocument != null) {
      await _readPickedFile(back: back);
      return;
    }
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => SelfieCameraPage(
          lensDirection: CameraLensDirection.back,
          title: 'Capture ${back ? 'Back' : 'Front'}',
          captureLabel: 'Capture ${back ? 'Back' : 'Front'}',
          maxBytes: 15 * 1024 * 1024,
          preserveOriginal: true,
        ),
      ),
    );

    if (bytes == null) return;
    if (!mounted) return;
    if (bytes.length > 15 * 1024 * 1024) {
      setState(() => errorText = 'Each KYC file must be 15 MB or smaller');
      return;
    }
    setState(() {
      final file = PickedBytesFile(
        name: '${DateTime.now().millisecondsSinceEpoch}.jpg',
        bytes: bytes,
      );
      if (back) {
        selectedBackFile = file;
      } else {
        selectedFile = file;
      }
      errorText = null;
    });
  }

  bool _validateFile(PickedBytesFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    if (!const {
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'heic',
      'heif',
    }.contains(extension)) {
      setState(
        () => errorText = 'Choose a PDF, JPG, PNG, WebP, HEIC or HEIF file',
      );
      return false;
    }
    if (file.bytes.isEmpty) {
      setState(() => errorText = 'Unable to read the selected file');
      return false;
    }
    if (file.size > 15 * 1024 * 1024) {
      setState(() => errorText = 'Each KYC file must be 15 MB or smaller');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (fullName.isEmpty || bankDetails == null) {
      setState(() => errorText = 'Complete your personal and bank details');
      return;
    }
    final file = selectedFile;
    if (selfieFile == null || signatureFile == null) {
      setState(
        () => errorText = 'Add your selfie and signature before submitting',
      );
      return;
    }

    if (file == null) {
      setState(() => errorText = 'Choose a KYC file first');
      return;
    }

    if (documentType == 'AADHAAR' && selectedBackFile == null) {
      setState(() => errorText = 'Add both the front and back of Aadhaar');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
    });

    try {
      await authService.submitKyc(
        accessToken: widget.accessToken,
        documentType: documentType,
        fullName: fullName,
        bankDetails: bankDetails,
        selfieFile: selfieFile!,
        signatureFile: signatureFile!,
        file: documentType == 'AADHAAR'
            ? file.renamed('aadhaar-front-${file.name}')
            : file,
        backFile: documentType == 'AADHAAR'
            ? selectedBackFile!.renamed(
                'aadhaar-back-${selectedBackFile!.name}',
              )
            : null,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(
            Icons.hourglass_top_rounded,
            size: 56,
            color: Color(0xFF2563EB),
          ),
          content: const SizedBox(
            width: 320,
            child: Text(
              'Your application has been submitted.\nPlease wait for review.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const AppText('OK'),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        errorText = clientErrorMessage(
          error,
          fallback: 'Unable to submit KYC. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _personalDetails() async {
    final controller = TextEditingController(text: fullName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppText('Personal Details'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('Full name as on your identity document'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 2) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const AppText('Save'),
          ),
        ],
      ),
    );
    if (value != null && mounted) setState(() => fullName = value);
  }

  Future<void> _bankDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => BankDetailsPage(
          initial: bankDetails ?? {'accountHolder': fullName},
          onContinue: (value) {
            setState(() => bankDetails = value);
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (mounted && bankDetails != null) _goTo(5);
  }
}
