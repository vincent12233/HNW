import 'package:flutter/material.dart';

import '../app_config.dart';

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppConfig.backgroundColor,
      colorScheme: ColorScheme.fromSeed(seedColor: AppConfig.primaryColor),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppConfig.borderColor),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: const DividerThemeData(color: AppConfig.borderColor),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppConfig.borderColor),
        ),
      ),
    );
  }
}
