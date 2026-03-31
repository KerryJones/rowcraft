import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RowCraftTheme {
  RowCraftTheme._();

  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color deepNavy = Color(0xFF0D47A1);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceContainer = Color(0xFF1E1E1E);
  static const Color surfaceContainerHigh = Color(0xFF2C2C2C);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color warningAmber = Color(0xFFFFB300);
  static const Color errorRose = Color(0xFFEF5350);
  static const Color successGreen = Color(0xFF66BB6A);
  static const Color metricWhite = Color(0xFFF5F5F5);
  static const Color subtleGrey = Color(0xFF9E9E9E);

  // Segment type colors — must match web (apps/web/src/app.css)
  static const Color segmentWork = Color(0xFF3B82F6);     // blue-500
  static const Color segmentRest = Color(0xFF6B7280);     // gray-500
  static const Color segmentWarmup = Color(0xFF22C55E);   // green-500
  static const Color segmentCooldown = Color(0xFFEAB308); // yellow-500

  // HR zone colors (5-zone model)
  static const Color hrZone1 = Color(0xFF66BB6A);   // recovery — green
  static const Color hrZone2 = Color(0xFF29B6F6);   // endurance — light blue
  static const Color hrZone3 = Color(0xFFFFB300);   // tempo — amber
  static const Color hrZone4 = Color(0xFFFF7043);   // threshold — deep orange
  static const Color hrZone5 = Color(0xFFEF5350);   // VO2 max — red

  static ThemeData get dark {
    const colorScheme = ColorScheme.dark(
      primary: primaryBlue,
      onPrimary: Colors.white,
      primaryContainer: deepNavy,
      onPrimaryContainer: Colors.white,
      secondary: accentTeal,
      onSecondary: Colors.black,
      surface: surfaceDark,
      onSurface: metricWhite,
      error: errorRose,
      onError: Colors.white,
      surfaceContainerHighest: surfaceContainerHigh,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaceDark,
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.jetBrainsMono(
          fontSize: 72,
          fontWeight: FontWeight.w700,
          color: metricWhite,
          letterSpacing: -2,
        ),
        displayMedium: GoogleFonts.jetBrainsMono(
          fontSize: 48,
          fontWeight: FontWeight.w600,
          color: metricWhite,
          letterSpacing: -1,
        ),
        displaySmall: GoogleFonts.jetBrainsMono(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: metricWhite,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: subtleGrey,
          letterSpacing: 1.2,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: subtleGrey,
          letterSpacing: 1.0,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: metricWhite,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: metricWhite,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: metricWhite,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: metricWhite,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: metricWhite,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: subtleGrey,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        foregroundColor: metricWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: metricWhite,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerHigh,
        selectedColor: primaryBlue.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: metricWhite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.inter(color: subtleGrey),
        hintStyle: GoogleFonts.inter(color: subtleGrey),
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceContainerHigh,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceContainer,
        selectedItemColor: primaryBlue,
        unselectedItemColor: subtleGrey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainer,
        indicatorColor: primaryBlue.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryBlue);
          }
          return const IconThemeData(color: subtleGrey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryBlue,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            color: subtleGrey,
          );
        }),
        elevation: 8,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
