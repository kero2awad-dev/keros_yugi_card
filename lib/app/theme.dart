import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color backgroundBlack = Color(0xFF0A0A0A);
  static const Color cardGrey = Color(0xFF1A1A1A);
  static const Color textWhite = Color(0xFFF5F5F5);
  static const Color accentGold = Color(0xFFFFD700);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primaryGold,
    scaffoldBackgroundColor: backgroundBlack,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGold,
      brightness: Brightness.dark,
      primary: primaryGold,
      secondary: accentGold,
      surface: cardGrey,
      background: backgroundBlack,
    ),
    textTheme: GoogleFonts.latoTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.cinzel(
        color: primaryGold,
        fontWeight: FontWeight.bold,
        fontSize: 32,
      ),
      titleLarge: GoogleFonts.cinzel(
        color: primaryGold,
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardGrey,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryGold.withOpacity(0.2), width: 1),
      ),
    ),
  );
}
