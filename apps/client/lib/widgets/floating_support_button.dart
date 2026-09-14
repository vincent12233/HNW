import 'package:flutter/material.dart';

import '../l10n/app_language.dart';

/// Compact right-edge support tab, sized like the product reference screenshot.
class FloatingSupportButton extends StatefulWidget {
  const FloatingSupportButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<FloatingSupportButton> createState() => _FloatingSupportButtonState();
}

class _FloatingSupportButtonState extends State<FloatingSupportButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(begin: const Offset(1.1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Customer Service',
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            elevation: 6,
            shadowColor: const Color(0x4D000000),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(8),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(8),
              ),
              onTap: widget.onTap,
              child: Ink(
                width: 26,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E88E5),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                ),
                child: const Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: AppText(
                            'Customer Service',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white, width: 1),
                            ),
                          ),
                          child: Icon(
                            Icons.headset_mic_rounded,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
