import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===========================================================================
  // COLORS
  // ===========================================================================

  static const Color lightPrimary = Color(0xFFCC5803);
  static const Color lightOnPrimary = Color(0xFFFAF3E0);
  static const Color lightSecondary = Color(0xFF2A9D8F);
  static const Color lightOnSecondary = Color(0xFFFAF3E0);
  static const Color lightAccent = Color(0xFFE5A836);
  static const Color lightBackground = Color(0xFFFAF3E0);
  static const Color lightSurface = Color(0xFFF2E8CF);
  static const Color lightOnSurface = Color(0xFF5C4033);
  static const Color lightPrimaryText = Color(0xFF3D2B1F);
  static const Color lightSecondaryText = Color(0xFF7A6356);
  static const Color lightHint = Color(0xFFA69083);
  static const Color lightError = Color(0xFFBC3908);
  static const Color lightOnError = Color(0xFFFAF3E0);
  static const Color lightSuccess = Color(0xFF386641);
  static const Color lightDivider = Color(0xFFD9C5B2);

  static const Color darkPrimary = Color(0xFFFF7B1C);
  static const Color darkOnPrimary = Color(0xFF1A1411);
  static const Color darkSecondary = Color(0xFF48C9B0);
  static const Color darkOnSecondary = Color(0xFF1A1411);
  static const Color darkAccent = Color(0xFFF4C430);
  static const Color darkBackground = Color(0xFF1A1411);
  static const Color darkSurface = Color(0xFF2D241E);
  static const Color darkOnSurface = Color(0xFFFAF3E0);
  static const Color darkPrimaryText = Color(0xFFFAF3E0);
  static const Color darkSecondaryText = Color(0xFFD9C5B2);
  static const Color darkHint = Color(0xFF7A6356);
  static const Color darkError = Color(0xFFFF6B35);
  static const Color darkOnError = Color(0xFF1A1411);
  static const Color darkSuccess = Color(0xFFA7C957);
  static const Color darkDivider = Color(0xFF4A3B31);

  // ===========================================================================
  // SPACING
  // ===========================================================================

  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ===========================================================================
  // RADII
  // ===========================================================================

  static const double radiusSm = 4.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 9999.0;

  // ===========================================================================
  // SHADOWS
  // ===========================================================================

  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color(0xFF3D2B1F).withValues(alpha: 0.2),
          offset: const Offset(2, 2),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color(0xFF3D2B1F).withValues(alpha: 0.3),
          offset: const Offset(4, 4),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowLg => [
        BoxShadow(
          color: const Color(0xFF3D2B1F).withValues(alpha: 0.4),
          offset: const Offset(6, 6),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get shadowXl => [
        BoxShadow(
          color: const Color(0xFF3D2B1F).withValues(alpha: 0.5),
          offset: const Offset(8, 8),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ];

  // ===========================================================================
  // THEMES
  // ===========================================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        error: lightError,
        onError: lightOnError,
        surface: lightSurface,
        onSurface: lightOnSurface,
        outline: lightDivider,
        tertiary: lightAccent,
      ),
      scaffoldBackgroundColor: lightBackground,
      dividerColor: lightDivider,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: lightOnSurface),
        titleTextStyle: TextStyle(
          color: lightOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(
        color: lightOnSurface,
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: lightOnSurface, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightOnSurface, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightOnSurface, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightPrimary, width: 3),
        ),
        hintStyle: GoogleFonts.spaceGrotesk(color: lightHint),
        labelStyle: GoogleFonts.archivo(color: lightOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: spacingLg, vertical: spacingMd),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: lightPrimary,
        onPrimary: lightOnPrimary,
        secondary: lightSecondary,
        onSecondary: lightOnSecondary,
        error: darkError,
        onError: darkOnError,
        surface: darkSurface,
        onSurface: darkOnSurface,
        outline: darkDivider,
        tertiary: lightAccent,
      ),
      scaffoldBackgroundColor: darkBackground,
      dividerColor: darkDivider,
      textTheme: _buildTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: darkOnSurface),
        titleTextStyle: TextStyle(
          color: darkOnSurface,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      iconTheme: const IconThemeData(
        color: darkOnSurface,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: darkOnSurface, width: 2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkOnSurface, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: darkOnSurface, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: lightPrimary, width: 3),
        ),
        hintStyle: GoogleFonts.spaceGrotesk(color: darkSecondaryText),
        labelStyle: GoogleFonts.archivo(color: darkOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightOnPrimary,
          elevation: 0,
          textStyle: GoogleFonts.archivo(fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: spacingLg, vertical: spacingMd),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      headlineLarge: GoogleFonts.archivo(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
      headlineMedium: GoogleFonts.archivo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineSmall: GoogleFonts.archivo(
        fontSize: 24, // Added for convenience
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleLarge: GoogleFonts.archivo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      titleMedium: GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleSmall: GoogleFonts.spaceGrotesk(
        // Added for convenience
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      bodyLarge: GoogleFonts.spaceGrotesk(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: GoogleFonts.archivo(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelMedium: GoogleFonts.archivo(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
      labelSmall: GoogleFonts.archivo(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );
  }
}
