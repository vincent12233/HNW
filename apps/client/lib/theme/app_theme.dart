import 'package:flutter/material.dart';

import '../app_config.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppConfig.backgroundColor,
      colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor)
          .copyWith(
            primary: AppConfig.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: AppConfig.textPrimaryColor,
          ),
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Roboto',
          color: AppConfig.textPrimaryColor,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Roboto',
          color: AppConfig.textPrimaryColor,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Roboto',
          color: AppConfig.textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Roboto',
          color: AppConfig.textPrimaryColor,
          fontSize: 14,
          height: 1.35,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        shadowColor: Color(0x140F172A),
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppConfig.textPrimaryColor,
        ),
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppConfig.borderColor),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 76,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 25)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppConfig.borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppConfig.borderColor),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          color: AppConfig.textSecondaryColor,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
      ),
    );
  }
}
