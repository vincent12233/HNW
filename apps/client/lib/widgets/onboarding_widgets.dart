import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';

InputDecoration onboardingInput(String hint) => InputDecoration(
  hintText: tr(hint),
  hintStyle: const TextStyle(fontSize: 12, color: AppConfig.textSecondaryColor),
  filled: true,
  fillColor: const Color(0xFFFAFBFE),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: Color(0xFFF0F2F6)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: Color(0xFFF0F2F6)),
  ),
);

class FinvestWordmark extends StatelessWidget {
  const FinvestWordmark({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      AppText(
        'FinVest',
        style: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          color: Color(0xFF111A55),
        ),
      ),
      SizedBox(height: 3),
      AppText(
        'India Trading',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111A55),
        ),
      ),
      SizedBox(height: 2),
      AppText(
        'Smart Trading. Real Growth.',
        style: TextStyle(fontSize: 10, color: AppConfig.textSecondaryColor),
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
    color: const Color(0xFFF7F9FD),
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
