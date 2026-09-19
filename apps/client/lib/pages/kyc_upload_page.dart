import '../l10n/app_language.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/picked_bytes_file.dart';
import '../services/auth_service.dart';
import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import '../widgets/kyc_signature_pad.dart';
import '../widgets/aadhaar_mark.dart';
import '../utils/client_error_message.dart';
import '../widgets/onboarding_widgets.dart';
import 'bank_details_page.dart';
import 'selfie_camera_page.dart';

class KycUploadPage extends StatefulWidget {
  const KycUploadPage({super.key, this.accessToken});

  final String? accessToken;

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
    _loadStatus();
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
                  if (!_reviewLocked && step == 1) ...[
                    if (documentType == 'AADHAAR')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppText(
                              '1  Front',
                              style: TextStyle(color: AppConfig.primaryColor),
                            ),
                            AppText('2  Back'),
                            AppText('3  Review'),
                          ],
                        ),
                      ),
                    _uploadPanel(back: false),
                    if (documentType == 'AADHAAR') ...[
                      const SizedBox(height: 20),
                      _uploadPanel(back: true),
                    ],
                  ] else if (!_reviewLocked && step == 2) ...[
                    _selfiePanel(),
                  ] else if (!_reviewLocked && step == 3) ...[
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
                      Image.memory(
                        signatureFile!.bytes,
                        height: 180,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      const AppText(
                        'Signature saved',
                        style: TextStyle(color: AppConfig.gainColor),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => signatureFile = null),
                        icon: const Icon(Icons.refresh),
                        label: const AppText('Retake Signature'),
                      ),
                    ],
                  ] else if (!_reviewLocked && step == 5) ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const AppText('Personal Details'),
                      subtitle: AppText(fullName),
                      trailing: TextButton(
                        onPressed: _personalDetails,
                        child: const AppText('Edit'),
                      ),
                    ),
                    if (bankDetails != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const AppText('Bank Details'),
                        subtitle: AppText(
                          '${bankDetails!['bankName']}\n${bankDetails!['accountHolder']}\n${bankDetails!['accountNumber']}',
                        ),
                        trailing: TextButton(
                          onPressed: _bankDetails,
                          child: const AppText('Edit'),
                        ),
                      ),
                    _reviewFile(selfieFile!, 'Selfie', editStep: 2),
                    _reviewFile(signatureFile!, 'Signature', editStep: 3),
                    _reviewFile(
                      selectedFile!,
                      documentType == 'PAN' ? 'PAN Card' : 'Aadhaar front',
                    ),
                    if (selectedBackFile != null && documentType == 'AADHAAR')
                      _reviewFile(selectedBackFile!, 'Aadhaar back'),
                    const SizedBox(height: 16),
                    const AppText(
                      'Check that all details are readable before submitting. Uploading documents does not mean your KYC has been approved.',
                      style: TextStyle(
                        color: AppConfig.textSecondaryColor,
                        height: 1.6,
                      ),
                    ),
                  ],
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
    final media = MediaQuery.of(context);
    final maxWidth = AuthLayout.formMaxWidth(media.size.width);
    final horizontal = AuthLayout.horizontalPadding(media.size.width);
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

    return DecoratedBox(
      key: const ValueKey('kyc-footer'),
      decoration: BoxDecoration(
        color: AuthLayout.pageBackground,
        border: const Border(
          top: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AuthFormError(message: errorText!),
                    ),
                  AuthSubmitButton(
                    label: label,
                    busy: isSubmitting,
                    onPressed: onPressed,
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 15,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: AppText(
                          'Used for identity verification',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: AuthLayout.helperSize,
                            color: AppColors.textTertiary,
                            height: 1.35,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

  Widget _uploadPanel({required bool back}) {
    final file = back ? selectedBackFile : selectedFile;
    final label = documentType == 'PAN'
        ? 'PAN Card Front'
        : back
        ? 'Aadhaar Back'
        : 'Aadhaar Front';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          '$label (Required)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const AppText(
          'Keep all corners visible and avoid glare.',
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: isSubmitting ? null : () => _pickFile(back: back),
          child: Container(
            height: 170,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFE),
              border: Border.all(color: AppConfig.borderColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                file != null &&
                    const {
                      'jpg',
                      'jpeg',
                      'png',
                      'webp',
                    }.contains(file.extension?.toLowerCase())
                ? Image.memory(
                    file.bytes,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        const Center(child: AppText('Preview unavailable')),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        file == null
                            ? Icons.add_photo_alternate_outlined
                            : Icons.description_outlined,
                        size: 42,
                        color: AppConfig.primaryColor,
                      ),
                      const SizedBox(height: 10),
                      AppText(
                        file?.name ?? 'Add $label',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isSubmitting ? null : () => _takePhoto(back: back),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: AppText('Capture ${back ? 'Back' : 'Front'}'),
        ),
        const SizedBox(height: 6),
        AppText(
          file == null
              ? 'PDF, JPG, PNG, WEBP, HEIC or HEIF · Maximum 15 MB'
              : '${file.name} · ${(file.size / 1024).toStringAsFixed(1)} KB',
          style: const TextStyle(
            fontSize: 10,
            color: AppConfig.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _reviewFile(PickedBytesFile file, String title, {int editStep = 1}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle, color: AppConfig.gainColor),
        title: AppText(title),
        subtitle: AppText(file.name),
        trailing: TextButton(
          onPressed: isSubmitting ? null : () => _goTo(editStep),
          child: const AppText('Edit'),
        ),
      );
  Widget _selfiePanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppConfig.primaryColor),
          ),
          padding: const EdgeInsets.all(8),
          child: ClipOval(
            child: selfieFile == null
                ? const ColoredBox(
                    color: Color(0xFFF5F8FF),
                    child: Icon(
                      Icons.person_outline,
                      size: 110,
                      color: AppConfig.primaryColor,
                    ),
                  )
                : Image.memory(selfieFile!.bytes, fit: BoxFit.cover),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const AppText(
        'Take a clear selfie in good lighting. Keep your face fully visible and remove glasses, hats and masks.',
        style: TextStyle(fontSize: 12, height: 1.6),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _pickSelfie(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const AppText('Capture Selfie'),
      ),
      const SizedBox(height: 8),
      const AppText(
        'Maximum 2 MB · Submitted for manual review',
        style: TextStyle(fontSize: 11),
      ),
    ],
  );

  Future<void> _pickSelfie(ImageSource source) async {
    try {
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
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
    );

    if (!mounted || picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    final file = PickedBytesFile(name: picked.name, bytes: bytes);
    if (!_validateFile(file)) return;
    setState(() {
      if (back) {
        selectedBackFile = file;
      } else {
        selectedFile = file;
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
