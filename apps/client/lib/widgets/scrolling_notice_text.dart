import 'package:flutter/material.dart';

/// Single-line horizontal marquee for CMS-driven notice text.
class ScrollingNoticeText extends StatefulWidget {
  const ScrollingNoticeText({
    super.key,
    required this.text,
    required this.style,
    this.gap = 48,
    this.pixelsPerSecond = 36,
    this.height = 18,
  });

  final String text;
  final TextStyle style;
  final double gap;
  final double pixelsPerSecond;
  final double height;

  @override
  State<ScrollingNoticeText> createState() => _ScrollingNoticeTextState();
}

class _ScrollingNoticeTextState extends State<ScrollingNoticeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0;
  double _viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
  }

  @override
  void didUpdateWidget(covariant ScrollingNoticeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.gap != widget.gap ||
        oldWidget.pixelsPerSecond != widget.pixelsPerSecond) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measureAndStart() {
    if (!mounted) return;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    _textWidth = painter.width;
    if (_viewportWidth <= 0 || _textWidth <= 0) {
      setState(() {});
      return;
    }

    final needsScroll = _textWidth > _viewportWidth - 4;
    if (!needsScroll) {
      _controller.stop();
      _controller.value = 0;
      setState(() {});
      return;
    }

    final distance = _textWidth + widget.gap;
    final seconds = (distance / widget.pixelsPerSecond).clamp(4.0, 40.0);
    _controller
      ..duration = Duration(milliseconds: (seconds * 1000).round())
      ..repeat();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          if ((width - _viewportWidth).abs() > 0.5) {
            _viewportWidth = width;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _measureAndStart(),
            );
          }

          final needsScroll = _textWidth > width - 4;
          if (!needsScroll) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            );
          }

          return ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final dx = -_controller.value * (_textWidth + widget.gap);
                return Stack(
                  children: [
                    Transform.translate(offset: Offset(dx, 0), child: child),
                    Transform.translate(
                      offset: Offset(dx + _textWidth + widget.gap, 0),
                      child: child,
                    ),
                  ],
                );
              },
              child: Text(
                widget.text,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
          );
        },
      ),
    );
  }
}
