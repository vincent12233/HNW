import 'package:flutter/material.dart';
import '../l10n/app_language.dart';

class MembershipTierBadge extends StatelessWidget {
  const MembershipTierBadge({super.key, required this.tier});
  final String? tier;
  @override
  Widget build(BuildContext context) {
    final normalized = tier?.trim().toUpperCase();
    final (icon, color) = switch (normalized) {
      'STANDARD' => (Icons.verified_user_outlined, const Color(0xffc8e6ff)),
      'SILVER' => (Icons.workspace_premium_outlined, const Color(0xffe1e7ef)),
      'GOLD' => (Icons.workspace_premium, const Color(0xffffdb76)),
      'PLATINUM' => (Icons.diamond_outlined, const Color(0xff91ece3)),
      _ => (Icons.help_outline, Colors.white70),
    };
    final display =
        ['STANDARD', 'SILVER', 'GOLD', 'PLATINUM'].contains(normalized)
        ? normalized!
        : '--';
    return Semantics(
      label: 'Membership tier $display',
      excludeSemantics: true,
      child: Wrap(
        spacing: 5,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          AppText(
            display,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
