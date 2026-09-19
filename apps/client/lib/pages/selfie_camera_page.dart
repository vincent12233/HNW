import '../l10n/app_language.dart';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../widgets/onboarding_widgets.dart';

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({
    super.key,
    this.lensDirection = CameraLensDirection.front,
    this.title = 'Capture Selfie',
    this.captureLabel = 'Capture Selfie',
    this.maxBytes = 2 * 1024 * 1024,
    this.preserveOriginal = false,
    this.debugForceError,
  });

  final CameraLensDirection lensDirection;
  final String title;
  final String captureLabel;
  final int maxBytes;
  final bool preserveOriginal;
  @visibleForTesting
  final String? debugForceError;

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
    if (widget.debugForceError != null) {
      _error = widget.debugForceError;
    } else {
      _open();
    }
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

  bool get _selfieMode =>
      widget.lensDirection == CameraLensDirection.front &&
      !widget.preserveOriginal;

  Widget _preview() {
    final camera = _camera!;
    if (!_selfieMode) {
      return Center(child: CameraPreview(camera));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = (constraints.biggest.shortestSide - 48).clamp(
          180.0,
          320.0,
        );
        return Center(
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandPrimary, width: 3),
            ),
            clipBehavior: Clip.antiAlias,
            child: ClipOval(child: CameraPreview(camera)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: AppText(widget.title),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: KycStatusSwitch(
              switchKey: _error != null
                  ? 'error'
                  : (_camera == null ? 'loading' : 'preview'),
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppText(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _open,
                              icon: const Icon(
                                Icons.refresh,
                                size: AppMotion.iconField,
                              ),
                              label: const AppText('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _camera == null
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _preview(),
            ),
          ),
          DecoratedBox(
            key: const ValueKey('kyc-camera-footer'),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: Color(0x33FFFFFF))),
            ),
            child: SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: AuthSubmitButton(
                    label: _capturing ? 'Capturing...' : widget.captureLabel,
                    busy: _capturing,
                    onPressed: _camera == null || _capturing ? null : _capture,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
