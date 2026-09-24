import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import '../theme/app_motion.dart';
import '../theme/app_colors.dart';
import 'support_ui_metrics.dart';

/// Compact right-edge support tab that scales with phone size.
class FloatingSupportButton extends StatefulWidget {
  const FloatingSupportButton({
    super.key,
    required this.onTap,
    this.label = 'Customer Service',
  });

  final VoidCallback onTap;
  final String label;

  @override
  State<FloatingSupportButton> createState() => _FloatingSupportButtonState();
}

class _FloatingSupportButtonState extends State<FloatingSupportButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _motionConfigured = false;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(1.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motionConfigured) return;
    _motionConfigured = true;
    // Respect the platform preference while keeping the control immediately
    // available to users who disable motion.
    if (AppMotion.reduce(context)) {
      _enter.value = 1;
    } else {
      _enter.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = SupportUiMetrics.of(context);
    final radius = BorderRadius.horizontal(left: Radius.circular(m.fabRadius));

    return Semantics(
      button: true,
      label: widget.label,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            elevation: 6,
            shadowColor: AppColors.brandDark.withValues(alpha: 0.24),
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onTap,
              child: Ink(
                width: m.fabWidth,
                height: m.fabHeight,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.brandPrimary,
                      AppColors.brandGradientEnd,
                    ],
                  ),
                  borderRadius: radius,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: AppText(
                            widget.label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: AppColors.textInverse,
                              fontSize: m.fabFontSize,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6 * m.scale),
                      child: SizedBox(
                        width: m.fabIconSize + 6,
                        height: m.fabIconSize + 6,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: AppColors.textInverse,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.headset_mic_rounded,
                            color: AppColors.textInverse,
                            size: m.fabIconSize,
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
