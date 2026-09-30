import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);
  static ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A53), brightness: brightness);
    return ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF7F9F8) : null,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero));
  }
}