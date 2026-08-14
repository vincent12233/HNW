import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../utils/client_error_message.dart';

class KycUploadPage extends StatefulWidget {
  const KycUploadPage({super.key, this.accessToken});

  final String? accessToken;

  @override
  State<KycUploadPage> createState() => _KycUploadPageState();
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1187FF), Color(0xFF5747FF)],
      ),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x442A74FF), blurRadius: 18)],
    ),
    child: const Icon(
      Icons.candlestick_chart_rounded,
      color: Colors.white,
      size: 27,
    ),
  );
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 4,
    decoration: BoxDecoration(
      gradient: active
          ? const LinearGradient(colors: [Color(0xFF078BFF), Color(0xFF6A52FF)])
          : null,
      color: active ? null : const Color(0xFF29405A),
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _KycBackgroundPainter extends CustomPainter {
  const _KycBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x452A74FF), Color(0x00050D18)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .82, size.height * .15),
              radius: size.width * .7,
            ),
          );
    canvas.drawRect(Offset.zero & size, glow);

    final line = Paint()
      ..color = const Color(0x183B82C4)
      ..strokeWidth = 1;
    for (double x = 20; x < size.width; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 20; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }

    final chart = Paint()
      ..color = const Color(0x334FA3FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..moveTo(0, size.height * .78)
      ..lineTo(size.width * .15, size.height * .72)
      ..lineTo(size.width * .28, size.height * .75)
      ..lineTo(size.width * .44, size.height * .62)
      ..lineTo(size.width * .58, size.height * .67)
      ..lineTo(size.width * .75, size.height * .52)
      ..lineTo(size.width, size.height * .43);
    canvas.drawPath(path, chart);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KycUploadPageState extends State<KycUploadPage> {
  final authService = AuthService();

  String documentType = 'AADHAAR';
  PlatformFile? selectedFile;
  PlatformFile? selectedBackFile;
  bool isSubmitting = false;
  String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050D18),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _KycBackgroundPainter()),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth > 700 ? 32 : 18,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _brandHeader(),
                        const SizedBox(height: 24),
                        _verificationCard(),
                        const SizedBox(height: 18),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: Color(0xFF74859D),
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Your documents are encrypted and securely submitted',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF74859D),
                                  fontSize: 12,
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
          ),
        ],
      ),
    );
  }

  Widget _brandHeader() => const Row(
    children: [
      _BrandMark(),
      SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'India Trading',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Secure identity verification',
            style: TextStyle(color: Color(0xFF8292AA), fontSize: 12),
          ),
        ],
      ),
    ],
  );

  Widget _verificationCard() => Container(
    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
    decoration: BoxDecoration(
      color: const Color(0xE6121E2D),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF243A54)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 38,
          offset: Offset(0, 18),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: _StepBar(active: false)),
            SizedBox(width: 8),
            Expanded(child: _StepBar(active: true)),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'STEP 2 OF 2  •  IDENTITY VERIFICATION',
          style: TextStyle(
            color: Color(0xFF4FA3FF),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1187FF), Color(0xFF5747FF)],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x552A74FF), blurRadius: 22),
            ],
          ),
          child: const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 31,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Complete your KYC',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Take a clear photo or choose an existing photo or file for verification.',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'IDENTITY DOCUMENT',
          style: TextStyle(
            color: Color(0xFF8DA0B8),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFFAAB8CA),
            ),
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF1769FF)
                  : const Color(0xFF0B1624),
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: Color(0xFF29405A)),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 15),
            ),
          ),
          segments: const [
            ButtonSegment(
              value: 'AADHAAR',
              label: Text('Aadhaar'),
              icon: Icon(Icons.credit_card_rounded),
            ),
            ButtonSegment(
              value: 'PAN',
              label: Text('PAN'),
              icon: Icon(Icons.badge_outlined),
            ),
          ],
          selected: {documentType},
          onSelectionChanged: (values) => setState(() {
            documentType = values.first;
            selectedFile = null;
            selectedBackFile = null;
            errorText = null;
          }),
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: isSubmitting ? null : () => _showSourcePicker(),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1522),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selectedFile == null
                    ? const Color(0xFF2D4764)
                    : const Color(0xFF25C48A),
                width: 1.2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  selectedFile == null
                      ? Icons.cloud_upload_outlined
                      : Icons.check_circle_rounded,
                  color: selectedFile == null
                      ? const Color(0xFF4FA3FF)
                      : const Color(0xFF25C48A),
                  size: 35,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedFile?.name ?? (documentType == 'AADHAAR'
                      ? 'Aadhaar front side'
                      : 'Take a photo or upload PAN'),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedFile == null
                      ? 'Camera, PDF, JPG, PNG or WEBP  •  Maximum 8 MB'
                      : '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB  •  Ready to submit',
                  style: const TextStyle(
                    color: Color(0xFF7F91A8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (documentType == 'AADHAAR') ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: isSubmitting ? null : () => _showSourcePicker(back: true),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1522),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selectedBackFile == null
                      ? const Color(0xFF2D4764)
                      : const Color(0xFF25C48A),
                  width: 1.2,
                ),
              ),
              child: Column(children: [
                Icon(
                  selectedBackFile == null
                      ? Icons.flip_to_back_outlined
                      : Icons.check_circle_rounded,
                  color: selectedBackFile == null
                      ? const Color(0xFF4FA3FF)
                      : const Color(0xFF25C48A),
                  size: 35,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedBackFile?.name ?? 'Aadhaar back side',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  selectedBackFile == null
                      ? 'Take a photo or choose an existing file'
                      : '${(selectedBackFile!.size / 1024).toStringAsFixed(1)} KB  •  Ready to submit',
                  style: const TextStyle(color: Color(0xFF7F91A8), fontSize: 12),
                ),
              ]),
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0x22FF5163),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x66FF5163)),
            ),
            child: Text(
              errorText!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFF8190), fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF078BFF), Color(0xFF5148FF)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(color: Color(0x552A74FF), blurRadius: 20),
              ],
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              onPressed: isSubmitting ? null : _submit,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.shield_outlined),
              label: Text(
                isSubmitting ? 'Submitting securely…' : 'Submit KYC for Review',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'Your relationship manager will review the submitted document.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7F91A8), fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );

  Future<void> _pickFile({bool back = false}) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty) {
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
        name: photo.name.toLowerCase().endsWith('.jpg') ||
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

  Future<void> _showSourcePicker({bool back = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                back
                    ? 'Add Aadhaar back side'
                    : documentType == 'AADHAAR'
                        ? 'Add Aadhaar front side'
                        : 'Add PAN document',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _takePhoto(back: back);
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take a photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _pickFile(back: back);
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Choose photo or file'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final file = selectedFile;

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
            'We detected this as $recognizedType. Your account is now waiting for business review.',
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
}
