import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../app_config.dart';
import '../services/auth_service.dart';

class KycUploadPage extends StatefulWidget {
  const KycUploadPage({super.key, required this.phone});

  final String phone;

  @override
  State<KycUploadPage> createState() => _KycUploadPageState();
}

class _KycUploadPageState extends State<KycUploadPage> {
  final authService = AuthService();

  String documentType = 'AADHAAR';
  PlatformFile? selectedFile;
  bool isSubmitting = false;
  String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 46,
                  color: AppConfig.primaryColor,
                ),
                const SizedBox(height: 14),
                const Text(
                  'KYC Verification',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload Aadhaar or PAN. Your relationship manager will review it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'AADHAAR',
                      label: Text('Aadhaar'),
                      icon: Icon(Icons.credit_card),
                    ),
                    ButtonSegment(
                      value: 'PAN',
                      label: Text('PAN'),
                      icon: Icon(Icons.badge_outlined),
                    ),
                  ],
                  selected: {documentType},
                  onSelectionChanged: (values) {
                    setState(() {
                      documentType = values.first;
                    });
                  },
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: isSubmitting ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(selectedFile?.name ?? 'Choose KYC file'),
                ),
                if (selectedFile != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${selectedFile!.name} - ${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit KYC'),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppConfig.lossColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    setState(() {
      selectedFile = result.files.single;
      errorText = null;
    });
  }

  Future<void> _submit() async {
    final file = selectedFile;

    if (file == null) {
      setState(() => errorText = 'Choose a KYC file first');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorText = null;
    });

    try {
      final recognizedType = await authService.submitKyc(
        phone: widget.phone,
        documentType: documentType,
        file: file,
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
        errorText = error.toString();
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
