import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'India Trading';
  static const String shortName = 'IT';
  static const String slogan = 'Professional. Fast. Simple.';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const Color primaryColor = Color(0xFF143D8D);
  static const Color gainColor = Color(0xFF16A34A);
  static const Color lossColor = Color(0xFFDC2626);
  static const Color neutralColor = Color(0xFF6B7280);
  static const Color backgroundColor = Color(0xFFF6F8FC);
  static const Color textPrimaryColor = Color(0xFF1F2937);
}
