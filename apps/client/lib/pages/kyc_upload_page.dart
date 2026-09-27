import '../l10n/app_language.dart';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/picked_bytes_file.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import '../widgets/kyc_signature_pad.dart';
import '../widgets/aadhaar_mark.dart';
import '../utils/client_error_message.dart';
import '../widgets/onboarding_widgets.dart';
import 'bank_details_page.dart';
import 'selfie_camera_page.dart';

part 'kyc_upload_page_overview_section.dart';
part 'kyc_upload_page_steps_section.dart';
part 'kyc_upload_page_upload_section.dart';
part 'kyc_upload_page_submission_section.dart';

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
  final Future<PickedBytesFile?> Function()? pickSelfie;
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

  void _setState(VoidCallback fn) => setState(fn);

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
                            if (step == 0 || _reviewLocked)
                              ..._overviewChildren()
                            else
                              KycFadeIn(
                                switchKey: step,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (step == 1) ..._documentStep(),
                                    if (step == 2) ..._selfieStep(),
                                    if (step == 3) ..._signatureStep(),
                                    if (step == 5) ..._reviewStep(),
                                  ],
                                ),
                              ),
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
}
