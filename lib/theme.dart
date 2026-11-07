import 'package:flutter/material.dart';

const clay = Color(0xFFD97757);
const clayDeep = Color(0xFFB85F43);
const cream = Color(0xFFF7F3EA);
const paper = Color(0xFFFFFCF6);
const ink = Color(0xFF1F1E1D);
const inkMuted = Color(0xFF6F6A62);
const hairline = Color(0x1F1F1E1D);

const darkBg = Color(0xFF171614);
const darkSurface = Color(0xFF201F1C);
const darkInk = Color(0xFFF2EEE6);
const darkMuted = Color(0xFFA8A197);

abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final bg = dark ? darkBg : cream;
    final surface = dark ? darkSurface : paper;
    final fg = dark ? darkInk : ink;
    final muted = dark ? darkMuted : inkMuted;
    final scheme = ColorScheme.fromSeed(
      seedColor: clay,
      brightness: brightness,
    ).copyWith(
      primary: clay,
      onPrimary: Colors.white,
      surface: bg,
      onSurface: fg,
      surfaceContainerHighest: surface,
      outline: dark ? const Color(0x33FFFFFF) : hairline,
      outlineVariant: dark ? const Color(0x22FFFFFF) : const Color(0x141F1E1D),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: scheme.outlineVariant,
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'serif',
          fontSize: 42,
          height: 1.02,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: fg,
        ),
        displayMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 32,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.6,
          color: fg,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'serif',
          fontSize: 25,
          height: 1.2,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: fg),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: fg),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: muted),
        labelSmall: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
          color: muted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: fg,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: clay,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(0, 50),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: muted.withValues(alpha: 0.8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: clay, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: fg,
        contentTextStyle: TextStyle(color: bg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
