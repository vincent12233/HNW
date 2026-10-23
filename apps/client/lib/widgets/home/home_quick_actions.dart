import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'home_action_button.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.onDeposit,
    required this.onWithdraw,
    required this.onTrade,
  });

  final VoidCallback onDeposit;
  final VoidCallback onWithdraw;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      HomeActionButton(
        label: tr('Add Money'),
        subtitle: tr('Instant Deposit'),
        icon: Icons.add_card_outlined,
        color: AppColors.brandPrimary,
        onTap: onDeposit,
        showChevron: false,
      ),
      HomeActionButton(
        label: tr('Withdraw'),
        subtitle: tr('Withdraw to Bank'),
        icon: Icons.account_balance_outlined,
        color: AppColors.gain,
        onTap: onWithdraw,
      ),
      HomeActionButton(
        label: tr('Trade'),
        subtitle: tr('Explore stocks and place orders'),
        icon: Icons.show_chart_rounded,
        color: AppColors.info,
        onTap: onTrade,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns = constraints.maxWidth >= 280 * scale ? 2 : 1;
        final width =
            (constraints.maxWidth - AppSpacing.sm * (columns - 1)) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final action in actions) SizedBox(width: width, child: action),
          ],
        );
      },
    );
  }
}
