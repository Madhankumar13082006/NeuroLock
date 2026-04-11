import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF7C5CBF);
  static const primaryLight = Color(0xFF9B7FD4);
  static const bg = Color(0xFF1A1A2E);
  static const surface = Color(0xFF242438);
  static const card = Color(0xFF2D2D44);
  static const cardBorder = Color(0xFF3A3A55);
  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF9090B0);
  static const success = Color(0xFF4CAF50);
  static const danger = Color(0xFFEF5350);
  static const amber = Color(0xFFFFC107);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryLight,
          surface: surface,
          background: bg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF666680),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.5)
                : const Color(0xFF3A3A55),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
            elevation: 0,
          ),
        ),
      );
}
