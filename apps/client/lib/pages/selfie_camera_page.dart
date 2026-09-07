import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SelfieCameraPage extends StatefulWidget {
  const SelfieCameraPage({super.key});
  @override
  State<SelfieCameraPage> createState() => _SelfieCameraPageState();
}

class _SelfieCameraPageState extends State<SelfieCameraPage> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;
  bool _capturing = false;
  int _generation = 0;
  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _open(); }
  Future<void> _open() async {
    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      final front = cameras.where((c) => c.lensDirection == CameraLensDirection.front).firstOrNull;
      if (front == null) throw StateError('This device has no front camera.');
      final controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted || generation != _generation) { await controller.dispose(); return; }
      setState(() { _camera = controller; _error = null; });
    } catch (_) { if (mounted && generation == _generation) setState(() => _error = 'Unable to open the front camera. Allow camera access in your phone settings.'); }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _generation++;
      final camera = _camera; _camera = null; camera?.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) { _open(); }
  }
  @override
  void dispose() { _generation++; WidgetsBinding.instance.removeObserver(this); _camera?.dispose(); super.dispose(); }
  Future<void> _capture() async {
    final camera = _camera;
    if (_capturing || camera == null || !camera.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final photo = await camera.takePicture();
      final bytes = await photo.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 720, allowUpscaling: false);
      final frame = await codec.getNextFrame();
      final encoded = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose(); codec.dispose();
      if (encoded == null || encoded.lengthInBytes > 2 * 1024 * 1024) throw StateError('Image too large');
      if (mounted) Navigator.pop<Uint8List>(context, encoded.buffer.asUint8List());
    } catch (_) { if (mounted) setState(() => _error = 'Unable to capture your selfie. Please try again.'); }
    finally { if (mounted) setState(() => _capturing = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Capture Selfie')),
    body: _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: const TextStyle(color: Colors.white)), TextButton(onPressed: _open, child: const Text('Retry'))])))
      : _camera == null ? const Center(child: CircularProgressIndicator()) : Center(child: CameraPreview(_camera!)),
    bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: FilledButton.icon(onPressed: _camera == null || _capturing ? null : _capture, icon: const Icon(Icons.camera_alt_outlined), label: Text(_capturing ? 'Capturing...' : 'Capture Selfie')))),
  );
}
