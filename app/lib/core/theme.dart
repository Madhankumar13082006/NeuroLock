import 'package:flutter/material.dart';

/// StayFree-inspired dark theme: near-black surfaces, soft purple accents.
class AppTheme {
  static const primary = Color(0xFFBB86FC);
  static const primaryDark = Color(0xFF9A67EA);
  static const bg = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const card = Color(0xFF1E1E1E);
  static const cardBorder = Color(0xFF2C2C2C);
  static const textPrimary = Color(0xFFE8E8E8);
  static const textSecondary = Color(0xFF9E9E9E);
  static const success = Color(0xFF4CAF50);
  static const danger = Color(0xFFCF6679);
  static const amber = Color(0xFFFFC107);
  static const navActiveBg = Color(0x33BB86FC);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primaryDark,
          surface: surface,
          onPrimary: Color(0xFF1A1A1A),
          onSurface: textPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: navActiveBg,
          labelTextStyle: WidgetStateProperty.resolveWith((s) {
            final selected = s.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? primary : textSecondary,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((s) {
            final selected = s.contains(WidgetState.selected);
            return IconThemeData(
              color: selected ? primary : textSecondary,
              size: 22,
            );
          }),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF757575),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary.withValues(alpha: 0.45)
                : const Color(0xFF3A3A3A),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: const Color(0xFF1A1A1A),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: textPrimary,
            side: const BorderSide(color: primary, width: 1.2),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
}
