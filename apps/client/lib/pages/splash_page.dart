import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/auth_layout.dart';
import '../widgets/onboarding_widgets.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({
    super.key,
    this.status = 'Checking saved session',
    this.detail,
  });

  final String status;
  final String? detail;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AuthLayout.pageBackground,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AuthBrandHeader(),
                const SizedBox(height: 28),
                AppText(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.4,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppText(
                    detail!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const AppText(
                  AppConfig.slogan,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
