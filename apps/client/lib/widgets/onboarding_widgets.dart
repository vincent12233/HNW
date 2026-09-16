import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

InputDecoration onboardingInput(String hint) => InputDecoration(
  hintText: tr(hint),
  hintStyle: AppTypography.bodySmall,
  filled: true,
  fillColor: AppColors.surfaceInput,
  contentPadding: EdgeInsets.symmetric(
    horizontal: AppSpacing.inputPaddingH,
    vertical: AppSpacing.inputPaddingV,
  ),
  border: OutlineInputBorder(
    borderRadius: AppRadius.borderMd,
    borderSide: const BorderSide(color: AppColors.border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderMd,
    borderSide: const BorderSide(color: AppColors.border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: AppRadius.borderMd,
    borderSide: const BorderSide(color: AppColors.brandPrimary, width: 1.5),
  ),
);

class FinvestWordmark extends StatelessWidget {
  const FinvestWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      AppText(
        AppConfig.appName,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: AppConfig.primaryDarkColor,
        ),
      ),
      SizedBox(height: 6),
      AppText(
        AppConfig.slogan,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppConfig.textSecondaryColor,
        ),
      ),
    ],
  );
}

class SecureFooter extends StatelessWidget {
  const SecureFooter({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 14,
            color: AppConfig.textSecondaryColor,
          ),
          SizedBox(width: 5),
          AppText(
            'Secure & Trusted',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      SizedBox(height: 6),
      AppText(
        'Your data is protected with bank-level security',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: AppConfig.textSecondaryColor),
      ),
    ],
  );
}

class VerificationBanner extends StatelessWidget {
  const VerificationBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.verified_user,
  });
  final String title, subtitle;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    color: AppColors.brandPrimarySoft,
    child: Row(
      children: [
        Icon(icon, size: 28, color: AppConfig.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              AppText(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppConfig.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
