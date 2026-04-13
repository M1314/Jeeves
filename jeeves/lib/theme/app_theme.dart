import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RetroColors {
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color electricBlue = Color(0xFF00FFFF);
  static const Color hotPink = Color(0xFFFF69B4);
  static const Color purple = Color(0xFF8B00FF);
  static const Color black = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkSurface2 = Color(0xFF16213E);
  static const Color white = Color(0xFFFFFFFF);
}

class RetroTheme {
  static ThemeData get theme {
    final base = ThemeData.dark();

    return base.copyWith(
      scaffoldBackgroundColor: RetroColors.black,
      colorScheme: const ColorScheme.dark(
        primary: RetroColors.neonGreen,
        secondary: RetroColors.electricBlue,
        tertiary: RetroColors.hotPink,
        surface: RetroColors.darkSurface,
        onPrimary: RetroColors.black,
        onSecondary: RetroColors.black,
        onSurface: RetroColors.neonGreen,
        error: RetroColors.hotPink,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.vt323(
          fontSize: 72,
          color: RetroColors.neonGreen,
          letterSpacing: 4,
        ),
        displayMedium: GoogleFonts.vt323(
          fontSize: 56,
          color: RetroColors.neonGreen,
          letterSpacing: 3,
        ),
        displaySmall: GoogleFonts.vt323(
          fontSize: 40,
          color: RetroColors.neonGreen,
          letterSpacing: 2,
        ),
        headlineLarge: GoogleFonts.vt323(
          fontSize: 32,
          color: RetroColors.electricBlue,
          letterSpacing: 2,
        ),
        headlineMedium: GoogleFonts.vt323(
          fontSize: 28,
          color: RetroColors.electricBlue,
          letterSpacing: 1,
        ),
        headlineSmall: GoogleFonts.vt323(
          fontSize: 24,
          color: RetroColors.electricBlue,
        ),
        bodyLarge: GoogleFonts.courierPrime(
          fontSize: 16,
          color: RetroColors.white,
        ),
        bodyMedium: GoogleFonts.courierPrime(
          fontSize: 14,
          color: RetroColors.white,
        ),
        bodySmall: GoogleFonts.courierPrime(
          fontSize: 12,
          color: RetroColors.white.withAlpha(200),
        ),
        labelSmall: GoogleFonts.pressStart2p(
          fontSize: 8,
          color: RetroColors.neonGreen,
        ),
        labelMedium: GoogleFonts.pressStart2p(
          fontSize: 10,
          color: RetroColors.neonGreen,
        ),
        labelLarge: GoogleFonts.pressStart2p(
          fontSize: 12,
          color: RetroColors.neonGreen,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RetroColors.darkSurface,
        foregroundColor: RetroColors.neonGreen,
        titleTextStyle: GoogleFonts.vt323(
          fontSize: 32,
          color: RetroColors.neonGreen,
          letterSpacing: 3,
        ),
        elevation: 4,
        shadowColor: RetroColors.neonGreen.withAlpha(128),
      ),
      cardTheme: CardThemeData(
        color: RetroColors.darkSurface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: RetroColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: RetroColors.neonGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: RetroColors.neonGreen, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: const BorderSide(color: RetroColors.electricBlue, width: 3),
        ),
        labelStyle: GoogleFonts.courierPrime(color: RetroColors.neonGreen),
        hintStyle: GoogleFonts.courierPrime(
          color: RetroColors.neonGreen.withAlpha(128),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: RetroColors.neonGreen,
          foregroundColor: RetroColors.black,
          textStyle: GoogleFonts.pressStart2p(fontSize: 10),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          side: const BorderSide(color: RetroColors.white, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: RetroColors.neonGreen,
        thickness: 1,
      ),
    );
  }

  static BoxDecoration get neonGlowDecoration => BoxDecoration(
        color: RetroColors.darkSurface,
        border: Border.all(color: RetroColors.neonGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonGreen.withAlpha(76),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      );

  static BoxDecoration get doubleCardDecoration => BoxDecoration(
        color: RetroColors.darkSurface,
        border: Border.all(color: RetroColors.neonGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: RetroColors.neonGreen.withAlpha(102),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(3, 3),
          ),
        ],
      );
}
