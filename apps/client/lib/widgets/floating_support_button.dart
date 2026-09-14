import 'package:flutter/material.dart';

import '../app_config.dart';
import '../l10n/app_language.dart';

/// Right-edge floating support tab with a soft presence animation.
class FloatingSupportButton extends StatefulWidget {
  const FloatingSupportButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<FloatingSupportButton> createState() => _FloatingSupportButtonState();
}

class _FloatingSupportButtonState extends State<FloatingSupportButton>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _pulse;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _slide = Tween<Offset>(begin: const Offset(1.15, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
        );
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
    _breathe = Tween<double>(begin: 1, end: 1.035).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Customer Support',
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _breathe,
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              elevation: 12,
              shadowColor: const Color(0x66071326),
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(16),
              ),
              child: InkWell(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(16),
                ),
                onTap: widget.onTap,
                child: Ink(
                  width: 44,
                  height: 156,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF3B7BFF),
                        AppConfig.primaryColor,
                        Color(0xFF0A3FB8),
                      ],
                      stops: [0, 0.45, 1],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppConfig.primaryColor.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(-2, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.support_agent_rounded,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                          Positioned(
                            right: -1,
                            top: -1,
                            child: FadeTransition(
                              opacity: _pulse,
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Expanded(
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: AppText(
                              'Support',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Icon(
                          Icons.chat_bubble_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
