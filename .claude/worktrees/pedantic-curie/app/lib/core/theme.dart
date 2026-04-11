import 'package:flutter/material.dart';

/// Production design tokens for Nokkon — calm, focused, dark.
///
/// The palette is intentionally narrow: a single violet accent, layered
/// near-black surfaces for hierarchy, and a warning amber + danger red
/// for the only two states the user should ever notice loudly.
class AppTheme {
  // ── Brand ────────────────────────────────────────────────
  static const primary = Color(0xFF8B5CF6); // Violet 500
  static const primaryDeep = Color(0xFF6D3FE0); // Violet 700
  static const primarySoft = Color(0xFFB39CFA); // Violet 300

  static const accent = Color(0xFF4A90D9); // Cool blue (gradient pair)

  // ── Surfaces ─────────────────────────────────────────────
  static const bg = Color(0xFF0E0E1A); // page background
  static const bgElevated = Color(0xFF15152A); // sheets / dialogs
  static const surface = Color(0xFF1B1B30); // input fields
  static const card = Color(0xFF1F1F38); // cards
  static const cardHover = Color(0xFF262645);
  static const cardBorder = Color(0xFF2C2C4A);
  static const divider = Color(0xFF22223A);

  // ── Text ─────────────────────────────────────────────────
  static const textPrimary = Color(0xFFF1F0FF);
  static const textSecondary = Color(0xFF9595B5);
  static const textTertiary = Color(0xFF6B6B8C);

  // ── Semantic ─────────────────────────────────────────────
  static const success = Color(0xFF4ADE80);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFFBBF24);
  static const info = Color(0xFF60A5FA);

  // Aliases kept for back-compat with existing call sites.
  static const amber = warning;

  // ── Gradients ────────────────────────────────────────────
  static const brandGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const lockGradient = LinearGradient(
    colors: [Color(0xFF0E0E1A), Color(0xFF1A0E2A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows ──────────────────────────────────────────────
  static List<BoxShadow> glow(Color color, {double opacity = 0.35}) => [
        BoxShadow(
          color: color.withValues(alpha: opacity),
          blurRadius: 24,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];

  static const cardShadow = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  // ── ThemeData ────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        canvasColor: bg,
        colorScheme: const ColorScheme.dark(
          primary: primary,
          secondary: primarySoft,
          surface: surface,
          onSurface: textPrimary,
          error: danger,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            color: textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
          titleLarge: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 15),
          bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
          bodySmall: TextStyle(color: textSecondary, fontSize: 13),
          labelLarge: TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.2,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? Colors.white
                : const Color(0xFFB0B0C8),
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary
                : const Color(0xFF3A3A55),
          ),
          trackOutlineColor:
              WidgetStateProperty.all(Colors.transparent),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
            borderSide: const BorderSide(color: primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: danger, width: 1.6),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textTertiary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF2C2C4A),
            disabledForegroundColor: textTertiary,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
            elevation: 0,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primarySoft,
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: card,
          contentTextStyle: const TextStyle(color: textPrimary),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerColor: divider,
      );
}
