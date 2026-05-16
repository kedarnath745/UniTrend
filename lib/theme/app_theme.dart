import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFF0A0A0F);
  static const Color cardBackground = Color(0xFF12121A);
  static const Color electricBlue = Color(0xFF00D4FF);

  static const Color gradientStart = Color(0xFFFF6B35);
  static const Color gradientMid = Color(0xFFE94B9C);
  static const Color gradientEnd = Color(0xFF7B61FF);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [gradientStart, gradientMid, gradientEnd],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static ThemeData buildAmoledTheme() {
    const amoledBg = Colors.black;
    const amoledCard = Color(0xFF0A0A0A);
    const seedColor = Color(0xFFFF6B35);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: amoledBg,
      surfaceContainerHighest: amoledCard,
      primary: gradientStart,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: amoledBg,
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        headlineLarge: GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium: GoogleFonts.syne(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
        headlineSmall: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70),
        bodySmall: GoogleFonts.dmSans(fontSize: 12, color: Colors.white54),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: amoledCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: amoledBg,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: amoledBg,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: gradientStart, fontSize: 12);
          }
          return GoogleFonts.dmSans(fontSize: 12, color: Colors.white54);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: amoledCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gradientMid, width: 1.5),
        ),
        labelStyle: GoogleFonts.dmSans(color: Colors.white54),
        hintStyle: GoogleFonts.dmSans(color: Colors.white38),
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    const seedColor = Color(0xFFFF6B35);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: background,
      surfaceContainerHighest: cardBackground,
      primary: gradientStart,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.dmSansTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).copyWith(
        headlineLarge: GoogleFonts.syne(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.syne(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        headlineSmall: GoogleFonts.syne(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.dmSans(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: Colors.white70,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          color: Colors.white54,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.syne(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              color: gradientStart,
              fontSize: 12,
            );
          }
          return GoogleFonts.dmSans(fontSize: 12, color: Colors.white54);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: gradientMid, width: 1.5),
        ),
        labelStyle: GoogleFonts.dmSans(color: Colors.white54),
        hintStyle: GoogleFonts.dmSans(color: Colors.white38),
      ),
    );
  }
}
