import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Kigo Welcome Intelligence — Theme
///
/// Based on the official Kigo Design System tokens.
/// Primary: Kigo 500 #FF6900
/// Background: Umbral 50 #FEF9F8
/// Cards: #FFFFFF on Umbral 50
class KigoTheme {
  KigoTheme._();

  // === PRIMARY — Kigo Orange ===
  static const Color kigo300 = Color(0xFFFFCBA4);
  static const Color kigo500 = Color(0xFFFF6900); // Primary
  static const Color kigo600 = Color(0xFFE55E00); // Pressed
  static const Color kigo900 = Color(0xFF7A2E00); // Text on light

  // === NEUTRAL — Umbral Warm ===
  static const Color umbral50 = Color(0xFFFEF9F8); // Page background
  static const Color umbral100 = Color(0xFFF6EEED); // Input bg, card hover
  static const Color umbral200 = Color(0xFFE9DEDD); // Borders, dividers
  static const Color umbral300 = Color(0xFFD5C5C3); // Skeleton base

  // === SEMANTIC ===
  static const Color green100 = Color(0xFFDCFCE7);
  static const Color green600 = Color(0xFF00A63E); // Success
  static const Color red100 = Color(0xFFFEE2E2);
  static const Color red500 = Color(0xFFFB2C36); // Error text
  static const Color red600 = Color(0xFFE7000B); // Error badge
  static const Color yellow50 = Color(0xFFFEFCE8);
  static const Color yellow400 = Color(0xFFFDC700); // Warning
  static const Color sky50 = Color(0xFFF0F9FF);
  static const Color sky900 = Color(0xFF024A70); // Info text

  // === GRAY SCALE ===
  static const Color slate900 = Color(0xFF0F172B); // Primary text
  static const Color slate500 = Color(0xFF62748E); // Secondary text
  static const Color gray200 = Color(0xFFE5E7EB); // Console sidebar
  static const Color gray400 = Color(0xFF9CA3AF); // Captions
  static const Color gray500 = Color(0xFF6B7280); // Supporting text
  static const Color white = Color(0xFFFFFFFF); // Cards

  // === CTA GRADIENTS ===
  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFF8848), Color(0xFFFF6900)],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF66BB6A), Color(0xFF00A63E)],
  );

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kigo500,
      brightness: Brightness.light,
      primary: kigo500,
      onPrimary: white,
      surface: umbral50,
      onSurface: slate900,
      error: red500,
      onError: white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: umbral50,
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: slate900,
        displayColor: slate900,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: umbral50,
        foregroundColor: slate900,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kigo500,
          foregroundColor: white,
          fixedSize: const Size.fromHeight(46),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: slate900,
          fixedSize: const Size.fromHeight(46),
          minimumSize: const Size(double.infinity, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: umbral200),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gray500,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: umbral100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: umbral200, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: umbral200, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kigo500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: red500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: GoogleFonts.inter(
          color: gray500,
          fontSize: 14,
        ),
        hintStyle: GoogleFonts.inter(
          color: gray400,
          fontSize: 15,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: umbral200),
        ),
        color: white,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: umbral200,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: umbral100,
        selectedColor: kigo500.withValues(alpha: 0.1),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide(color: umbral200),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: gray200,
        selectedIconTheme: const IconThemeData(color: slate900),
        unselectedIconTheme: IconThemeData(color: slate500),
        selectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: slate900,
        ),
        unselectedLabelTextStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: slate500,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
