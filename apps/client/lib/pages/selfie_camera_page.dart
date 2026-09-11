import '../l10n/app_language.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({
    super.key,
    this.lensDirection = CameraLensDirection.front,
    this.title = 'Capture Selfie',
    this.captureLabel = 'Capture Selfie',
    this.maxBytes = 2 * 1024 * 1024,
    this.preserveOriginal = false,
  });

  final CameraLensDirection lensDirection;
  final String title;
  final String captureLabel;
  final int maxBytes;
  final bool preserveOriginal;

  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage>
    with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _capturing = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> _open() async {
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      final selected = cameras
          .where((c) => c.lensDirection == widget.lensDirection)
          .firstOrNull;
      if (selected == null) {
        throw StateError('This device has no requested camera.');
      }
      final controller = CameraController(
        selected,
        widget.preserveOriginal
            ? ResolutionPreset.high
            : ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        final cameraName = widget.lensDirection == CameraLensDirection.back
            ? 'rear'
            : 'front';
        setState(
          () => _error =
              'Unable to open the $cameraName camera. Allow camera access in your phone settings.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _generation++;
      final camera = _camera;
      _camera = null;
      camera?.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _open();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_capturing || camera == null || !camera.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      if (widget.preserveOriginal) {
        if (bytes.length > widget.maxBytes) {
          throw StateError('Image too large');
        }
        if (mounted) {
          Navigator.pop<Uint8List>(context, bytes);
        }
        return;
      }
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 720,
        allowUpscaling: false,
      );
      final frame = await codec.getNextFrame();
      final encoded = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      frame.image.dispose();
      codec.dispose();
      if (encoded == null || encoded.lengthInBytes > widget.maxBytes) {
        throw StateError('Image too large');
      }
      if (mounted) {
        Navigator.pop<Uint8List>(context, encoded.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to capture the image. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: AppText(widget.title)),
    body: _error != null
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppText(_error!, style: const TextStyle(color: Colors.white)),
                  TextButton(onPressed: _open, child: const AppText('Retry')),
                ],
              ),
            ),
          )
        : _camera == null
        ? const Center(child: CircularProgressIndicator())
        : Center(child: CameraPreview(_camera!)),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton.icon(
          onPressed: _camera == null || _capturing ? null : _capture,
          icon: const Icon(Icons.camera_alt_outlined),
          label: AppText(_capturing ? 'Capturing...' : widget.captureLabel),
        ),
      ),
    ),
  );
}
