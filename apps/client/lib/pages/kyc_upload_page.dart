import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../app_config.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goTo(int nextStep) {
    if (nextStep == 4) { _bankDetails(); return; }
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      step = nextStep;
      errorText = null;
    });
  }

  String documentType = 'PAN';
  PlatformFile? selectedFile;
  PlatformFile? selectedBackFile;
  bool isSubmitting = false;
  String? errorText;
  int step = 0;
  PlatformFile? selfieFile;
  PlatformFile? signatureFile;
  Map<String, String>? bankDetails;
  String fullName = '';
  String? existingStatus, reviewNote;

  @override
  void initState() { super.initState(); _loadStatus(); }
  Future<void> _loadStatus() async {
    try {
      final status = await authService.kycDetails(accessToken: widget.accessToken);
      if (mounted) setState(() { existingStatus = status['status']?.toString(); reviewNote = status['reviewNote']?.toString(); });
    } catch (e) { if (mounted) setState(() => errorText = clientErrorMessage(e)); }
  }

  bool get documentsReady =>
      selectedFile != null &&
      (documentType != 'AADHAAR' || selectedBackFile != null);

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !isSubmitting && step == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !isSubmitting && step > 0) _goTo(step - 1);
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
        title: Text(
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
      bottomNavigationBar: _footer(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              if (existingStatus == 'PENDING' || existingStatus == 'APPROVED') ...[
                VerificationBanner(title: existingStatus == 'PENDING' ? 'Verification in Progress' : 'Verification Complete', subtitle: existingStatus == 'PENDING' ? 'Your documents are waiting for business review.' : 'Your account has been verified.'),
                const SizedBox(height: 20),
                if (reviewNote != null) Text(reviewNote!),
                TextButton.icon(onPressed: _loadStatus, icon: const Icon(Icons.refresh), label: const Text('Refresh Status')),
              ] else ...[
              if (existingStatus == 'REJECTED') Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(reviewNote ?? 'Please update your documents and submit again.', style: const TextStyle(color: AppConfig.lossColor))),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F8FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user,
                      color: AppConfig.primaryColor,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step == 0
                                ? 'Verification in Progress'
                                : step == 1
                                ? 'Add your identity document'
                                : step == 2
                                ? 'Take a clear selfie'
                                : step == 3
                                ? 'Provide your signature'
                                : 'Ready for your review',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step == 0 ? 'Securely verify your identity to access your account.' : step == 2 ? 'Please take a clear selfie in good lighting. Make sure your face is fully visible.' : step == 3 ? 'Sign on a white page using a dark pen and sign within the lines below.' : 'Use a clear, readable image of your own document.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppConfig.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (step == 0) ...[Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 8,
                children: [
                  const Text(
                    'Verification Progress',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  Flexible(child: Text(
                    '${[fullName.isNotEmpty, documentsReady, selfieFile != null, signatureFile != null, bankDetails != null].where((value) => value).length} of 6 completed',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppConfig.primaryColor,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: [fullName.isNotEmpty, documentsReady, selfieFile != null, signatureFile != null, bankDetails != null].where((value) => value).length / 6,
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: const Color(0xFFEBF0FA),
              ),
              const SizedBox(height: 24),
              ],
              if (step == 0) ...[
                const Text(
                  'Choose Identity Document',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _documentOption(
                        'PAN',
                        'PAN Card',
                        'Front photo required',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _documentOption(
                        'AADHAAR',
                        'Aadhaar Card',
                        'Front & back required',
                        Icons.fingerprint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'Verification Steps',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                _stepRow(
                  Icons.badge_outlined,
                  'Personal Details',
                  fullName.isEmpty ? 'Basic identity information' : fullName,
                  fullName.isNotEmpty,
                ),
                _stepRow(
                  Icons.photo_camera_outlined,
                  'Upload documents',
                  'Take a photo or choose a file',
                  documentsReady,
                ),
                _stepRow(
                  Icons.face_outlined,
                  'Selfie',
                  'A clear photo for manual review',
                  selfieFile != null,
                ),
                _stepRow(
                  Icons.draw_outlined,
                  'Signature',
                  'Sign using your finger or stylus',
                  signatureFile != null,
                ),
                _stepRow(
                  Icons.fact_check_outlined,
                  'Bank Details',
                  'Add your bank account information',
                  bankDetails != null,
                ),
                _stepRow(
                  Icons.fact_check_outlined,
                  'Review & submit',
                  'Your documents will be reviewed',
                  false,
                ),
              ] else if (step == 1) ...[
                if (documentType == 'AADHAAR') const Padding(padding: EdgeInsets.only(bottom: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('1  Front', style: TextStyle(color: AppConfig.primaryColor)), Text('2  Back'), Text('3  Review')])),
                _uploadPanel(back: false),
                if (documentType == 'AADHAAR') ...[
                  const SizedBox(height: 20),
                  _uploadPanel(back: true),
                ],
              ] else if (step == 2) ...[
                _selfiePanel(),
              ] else if (step == 3) ...[
                if (signatureFile == null)
                  KycSignaturePad(
                    onSaved: (bytes) => setState(() {
                      signatureFile = PlatformFile(
                        name: 'signature.png',
                        size: bytes.length,
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
                    signatureFile!.bytes!,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Signature saved',
                    style: TextStyle(color: AppConfig.gainColor),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => signatureFile = null),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake Signature'),
                  ),
                ],
              ] else ...[
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('Personal Details'), subtitle: Text(fullName), trailing: TextButton(onPressed: _personalDetails, child: const Text('Edit'))),
                if (bankDetails != null) ListTile(contentPadding: EdgeInsets.zero, title: const Text('Bank Details'), subtitle: Text('${bankDetails!['bankName']}\n${bankDetails!['accountHolder']}\n${bankDetails!['accountNumber']}'), trailing: TextButton(onPressed: _bankDetails, child: const Text('Edit'))),
                _reviewFile(selfieFile!, 'Selfie', editStep: 2),
                _reviewFile(signatureFile!, 'Signature', editStep: 3),
                _reviewFile(
                  selectedFile!,
                  documentType == 'PAN' ? 'PAN Card' : 'Aadhaar front',
                ),
                if (selectedBackFile != null && documentType == 'AADHAAR')
                  _reviewFile(selectedBackFile!, 'Aadhaar back'),
                const SizedBox(height: 16),
                const Text(
                  'Check that all details are readable before submitting. Uploading documents does not mean your KYC has been approved.',
                  style: TextStyle(
                    color: AppConfig.textSecondaryColor,
                    height: 1.6,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _footer() => SafeArea(
    top: false,
    child: Align(
      heightFactor: 1,
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorText!,
                    style: const TextStyle(color: AppConfig.lossColor),
                  ),
                ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : existingStatus == 'PENDING' || existingStatus == 'APPROVED'
                    ? () => Navigator.popUntil(context, (route) => route.isFirst)
                    : step == 5
                    ? _submit
                    : () {
                        if (step == 0 && fullName.isEmpty) { _personalDetails(); return; }
                        if (step == 1 && !documentsReady) {
                          setState(
                            () => errorText = documentType == 'AADHAAR'
                                ? 'Add both the front and back of Aadhaar'
                                : 'Add your PAN document',
                          );
                          return;
                        }
                        if (step == 2 && selfieFile == null) {
                          setState(
                            () => errorText = 'Add your selfie to continue',
                          );
                          return;
                        }
                        if (step == 3 && signatureFile == null) {
                          setState(
                            () => errorText = 'Save your signature to continue',
                          );
                          return;
                        }
                        _goTo(step + 1);
                      },
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(existingStatus == 'PENDING' || existingStatus == 'APPROVED' ? 'Back to Login' : step == 5 ? 'Submit KYC for Review' : step == 0 ? 'Continue Verification' : 'Continue'),
              ),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: AppConfig.textSecondaryColor,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Used for identity verification',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppConfig.textSecondaryColor,
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
  );

  Widget _documentOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = documentType == value;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        if (documentType != value) {
          selectedFile = null;
          selectedBackFile = null;
        }
        documentType = value;
        errorText = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF5F8FF) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppConfig.primaryColor : AppConfig.borderColor,
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
                  Icon(icon, color: AppConfig.primaryColor),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 17,
                  color: selected
                      ? AppConfig.primaryColor
                      : AppConfig.neutralColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(subtitle, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(
    IconData icon,
    String title,
    String subtitle,
    bool complete,
  ) => ListTile(
    onTap: title == 'Personal Details' ? _personalDetails : null,
    minTileHeight: 48,
    visualDensity: VisualDensity.compact,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: AppConfig.primaryColor, size: 22),
    title: Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    trailing: Icon(
      complete ? Icons.check_circle : Icons.chevron_right,
      color: complete ? AppConfig.gainColor : AppConfig.neutralColor,
      size: 18,
    ),
  );

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
        Text(
          '$label (Required)',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const Text(
          'Keep all corners visible and avoid glare.',
          style: TextStyle(fontSize: 11),
        ),
        const SizedBox(height: 12),
        Container(
          height: 170,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFE),
            border: Border.all(color: AppConfig.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: file?.bytes != null && file!.extension?.toLowerCase() != 'pdf'
              ? Image.memory(
                  file.bytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('Preview unavailable')),
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
                    Text(
                      file?.name ?? 'Add $label',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: isSubmitting ? null : () => _takePhoto(back: back),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text('Capture ${back ? 'Back' : 'Front'}'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: isSubmitting ? null : () => _pickFile(back: back),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Choose from Gallery'),
        ),
        const SizedBox(height: 6),
        Text(
          file == null
              ? 'PDF, JPG, PNG or WEBP · Maximum 8 MB'
              : '${file.name} · ${(file.size / 1024).toStringAsFixed(1)} KB',
          style: const TextStyle(
            fontSize: 10,
            color: AppConfig.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _reviewFile(PlatformFile file, String title, {int editStep = 1}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.check_circle, color: AppConfig.gainColor),
        title: Text(title),
        subtitle: Text(file.name),
        trailing: TextButton(
          onPressed: isSubmitting ? null : () => _goTo(editStep),
          child: const Text('Edit'),
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
                : Image.memory(selfieFile!.bytes!, fit: BoxFit.cover),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Take a clear selfie in good lighting. Keep your face fully visible and remove glasses, hats and masks.',
        style: TextStyle(fontSize: 12, height: 1.6),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: () => _pickSelfie(ImageSource.camera),
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Capture Selfie'),
      ),
      const SizedBox(height: 8),
      const Text(
        'Maximum 2 MB · Submitted for manual review',
        style: TextStyle(fontSize: 11),
      ),
    ],
  );

  Future<void> _pickSelfie(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final bytes = await Navigator.push<Uint8List>(context, MaterialPageRoute(builder: (_) => const SelfieCameraPage()));
        if (bytes != null && mounted) setState(() { selfieFile = PlatformFile(name: 'selfie.png', size: bytes.length, bytes: bytes); errorText = null; });
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
        selfieFile = PlatformFile(
          name: 'selfie.$extension',
          size: bytes.length,
          bytes: bytes,
        );
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
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }
    final picked = result.files.single;
    if (!_validateFile(picked)) return;
    setState(() {
      if (back) {
        selectedBackFile = picked;
      } else {
        selectedFile = picked;
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
    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 2400,
    );

    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 8 * 1024 * 1024) {
      setState(() => errorText = 'Each KYC file must be 8 MB or smaller');
      return;
    }
    setState(() {
      final file = PlatformFile(
        name:
            photo.name.toLowerCase().endsWith('.jpg') ||
                photo.name.toLowerCase().endsWith('.jpeg')
            ? photo.name
            : '${DateTime.now().millisecondsSinceEpoch}.jpg',
        size: bytes.length,
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

  bool _validateFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase() ?? '';
    if (!const {'pdf', 'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      setState(() => errorText = 'Choose a PDF, JPG, PNG or WebP file');
      return false;
    }
    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() => errorText = 'Unable to read the selected file');
      return false;
    }
    if (file.size > 8 * 1024 * 1024) {
      setState(() => errorText = 'Each KYC file must be 8 MB or smaller');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (fullName.isEmpty || bankDetails == null) { setState(() => errorText = 'Complete your personal and bank details'); return; }
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
      final recognizedType = await authService.submitKyc(
        accessToken: widget.accessToken,
        documentType: documentType,
        fullName: fullName,
        bankDetails: bankDetails,
        selfieFile: selfieFile!,
        signatureFile: signatureFile!,
        file: documentType == 'AADHAAR'
            ? PlatformFile(
                name: 'aadhaar-front-${file.name}',
                size: file.size,
                bytes: file.bytes,
              )
            : file,
        backFile: documentType == 'AADHAAR'
            ? PlatformFile(
                name: 'aadhaar-back-${selectedBackFile!.name}',
                size: selectedBackFile!.size,
                bytes: selectedBackFile!.bytes,
              )
            : null,
      );

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('KYC Submitted'),
          content: Text(
            'Your $recognizedType, selfie, signature and bank details have been submitted to your assigned business representative for review.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('OK'),
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
    final value = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: const Text('Personal Details'), content: TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name as on your identity document')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (controller.text.trim().length >= 2) Navigator.pop(context, controller.text.trim()); }, child: const Text('Save'))]));
    if (value != null && mounted) setState(() => fullName = value);
  }

  Future<void> _bankDetails() async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (context) => BankDetailsPage(initial: bankDetails ?? {'accountHolder': fullName}, onContinue: (value) { setState(() => bankDetails = value); Navigator.pop(context); })));
    if (mounted && bankDetails != null) _goTo(5);
  }
}
