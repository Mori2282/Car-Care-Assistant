import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData create(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xFF087C72),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 16, height: 1.35),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardTheme(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 52)),
      ),
    );
  }
}
