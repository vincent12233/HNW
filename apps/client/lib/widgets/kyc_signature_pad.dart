import '../l10n/app_language.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_radius.dart';
import '../theme/auth_layout.dart';
import '../widgets/onboarding_widgets.dart';

/// Normalized points preserve the signature when the layout width changes.
class KycSignaturePad extends StatefulWidget {
  const KycSignaturePad({
    super.key,
    required this.onSaved,
    required this.onChanged,
  });
  final ValueChanged<Uint8List> onSaved;
  final VoidCallback onChanged;

  @override
  State<KycSignaturePad> createState() => _KycSignaturePadState();
}

class _KycSignaturePadState extends State<KycSignaturePad> {
  final List<List<Offset>> _strokes = [];
  bool _saving = false;
  String? _error;

  void _point(Offset position, Size size, {bool start = false}) {
    if (_saving) return;
    widget.onChanged();
    setState(() {
      _error = null;
      if (start) _strokes.add([]);
      if (_strokes.isNotEmpty) {
        _strokes.last.add(
          Offset(
            (position.dx / size.width).clamp(0, 1),
            (position.dy / size.height).clamp(0, 1),
          ),
        );
      }
    });
  }

  void _clear() {
    if (_saving) return;
    setState(() {
      _strokes.clear();
      _error = null;
    });
    widget.onChanged();
  }

  Future<void> _save() async {
    final points = _strokes.expand((stroke) => stroke).toList();
    double distance = 0;
    for (final stroke in _strokes) {
      for (var i = 1; i < stroke.length; i++) {
        distance += (stroke[i] - stroke[i - 1]).distance;
      }
    }
    if (points.length < 5 || distance < .15) {
      setState(() => _error = 'Please draw your signature before saving.');
      return;
    }
    setState(() => _saving = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(900, 450);
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
      SignaturePainter(_strokes).paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(900, 450);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (!mounted) return;
      if (bytes == null) throw StateError('Signature encoding failed');
      widget.onSaved(bytes.buffer.asUint8List());
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to save the signature. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = (width * 0.5).clamp(140.0, 200.0);
          final size = Size(width, height);
          return DecoratedBox(
            decoration: BoxDecoration(
              color: AuthLayout.pageBackground,
              border: Border.all(color: AppColors.border),
              borderRadius: AppRadius.borderSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppMotion.tapTarget,
                      minWidth: AppMotion.tapTarget,
                    ),
                    child: Tooltip(
                      message: 'Clear',
                      child: TextButton.icon(
                        onPressed: _saving ? null : _clear,
                        icon: const Icon(Icons.close, size: AppMotion.iconInline),
                        label: const AppText('Clear'),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  height: height,
                  child: ClipRRect(
                    borderRadius: AppRadius.borderSm,
                    child: GestureDetector(
                      key: const ValueKey('signature-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) =>
                          _point(details.localPosition, size, start: true),
                      onPanUpdate: (details) =>
                          _point(details.localPosition, size),
                      child: CustomPaint(
                        painter: SignaturePainter(_strokes),
                        size: size,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const SizedBox(height: 12),
      const AppText(
        'Use your finger or a stylus. Your signature will be submitted with your identity documents.',
        style: TextStyle(
          fontSize: AuthLayout.helperSize,
          height: 1.4,
          letterSpacing: 0,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: 16),
      AuthOutlinedButton(
        label: _saving ? 'Saving…' : 'Save Signature',
        icon: Icons.draw,
        busy: _saving,
        onPressed: _save,
      ),
      KycStatusSwitch(
        switchKey: _error ?? 'none',
        child: _error == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppText(
                  _error!,
                  style: const TextStyle(color: AppColors.loss),
                ),
              ),
      ),
    ],
  );
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = size.width / 220
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * size.width, point.dy * size.height);
      }
      canvas.drawPath(path, pen);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
