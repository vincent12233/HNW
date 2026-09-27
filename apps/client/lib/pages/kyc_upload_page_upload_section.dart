part of 'kyc_upload_page.dart';

extension _KycUploadUploadSection on _KycUploadPageState {
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
      _setState(() {
        if (back) {
          selectedBackFile = null;
        } else {
          selectedFile = null;
        }
        errorText = null;
      });
    }
  }

  Future<void> _captureSelfie() async {
    try {
      final debugPick = widget.debugHarness?.pickSelfie;
      if (debugPick != null) {
        final file = await debugPick();
        if (!mounted || file == null) return;
        if (file.bytes.isEmpty || file.size > 2 * 1024 * 1024) {
          _setState(() => errorText = 'Choose an image no larger than 2 MB');
          return;
        }
        final extension = file.extension ?? _imageExtension(file.bytes);
        if (extension == null ||
            !const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          _setState(() => errorText = 'Choose a JPG, PNG or WebP image');
          return;
        }
        _setState(() {
          selfieFile = file;
          errorText = null;
        });
        return;
      }
      final bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => const SelfieCameraPage()),
      );
      if (bytes == null || !mounted) return;
      _setState(() {
        selfieFile = PickedBytesFile(name: 'selfie.png', bytes: bytes);
        errorText = null;
      });
    } catch (_) {
      if (mounted) {
        _setState(
          () => errorText =
              'Unable to open the front camera. Check camera permission and try again.',
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
        _setState(() => errorText = 'Unable to open files. Please try again.');
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
    _setState(() {
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
        _setState(
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
      _setState(() => errorText = 'Each KYC file must be 15 MB or smaller');
      return;
    }
    _setState(() {
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
      _setState(
        () => errorText = 'Choose a PDF, JPG, PNG, WebP, HEIC or HEIF file',
      );
      return false;
    }
    if (file.bytes.isEmpty) {
      _setState(() => errorText = 'Unable to read the selected file');
      return false;
    }
    if (file.size > 15 * 1024 * 1024) {
      _setState(() => errorText = 'Each KYC file must be 15 MB or smaller');
      return false;
    }
    return true;
  }

}
