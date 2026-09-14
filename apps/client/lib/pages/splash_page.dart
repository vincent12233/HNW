import '../l10n/app_language.dart';
import 'package:flutter/material.dart';
import '../app_config.dart';
import '../widgets/app_brand_logo.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAFF),
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFEEF5FF)],
        ),
      ),
      child: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: .72, end: 1).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBrandLogo(size: 86),
              SizedBox(height: 22),
              AppText(
                AppConfig.appName,
                style: TextStyle(
                  color: AppConfig.primaryDarkColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              AppText(
                AppConfig.slogan,
                style: TextStyle(
                  color: AppConfig.textSecondaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: 118,
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
  );
}
