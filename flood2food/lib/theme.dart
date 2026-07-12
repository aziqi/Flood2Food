import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- PALET DARK FINTECH (ATTITUDE) ---
  static const Color darkBackground = Color(0xFF06231D);
  static const Color darkSurface = Color(0xFF0C342C);
  static const Color neonYellow = Color(0xFFE3EF26);
  static const Color neonGreen = Color(0xFFE2FBCE);
  static const Color textWhite = Color(0xFFFFFDEE);
  
  // --- PALET PEARL LIGHT ---
  static const Color lightBackground = Color(0xFFF7FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkGreenAccent = Color(0xFF076653);
  static const Color textDark = Color(0xFF06231D);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: darkSurface,
        secondary: darkGreenAccent,
        surface: lightSurface,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textDark,
        displayColor: textDark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textDark,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0, // Zero allocation for shadows
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: darkSurface,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(), // Plump Pill Shape
        ),
      ),
      // Transisi default Material 3 (Zoom untuk Android, Cupertino untuk iOS)
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: neonYellow,
        secondary: neonGreen,
        surface: darkSurface,
        onSurface: textWhite,
      ),
      scaffoldBackgroundColor: darkBackground,
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textWhite,
        displayColor: textWhite,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textWhite,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0, // No expensive blur/shadows
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: neonYellow,
          foregroundColor: darkBackground, // Dark text on neon button
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
        ),
      ),
      // Transisi default Material 3 (Zoom untuk Android, Cupertino untuk iOS)
    );
  }
}
