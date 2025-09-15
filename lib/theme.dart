import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LightModeColors {
  static const lightPrimary = Color(0xFF684F8E);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightPrimaryContainer = Color(0xFFEAE0FF);
  static const lightOnPrimaryContainer = Color(0xFF23105F);
  static const lightSecondary = Color(0xFF635D70);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightTertiary = Color(0xFF7E525D);
  static const lightOnTertiary = Color(0xFFFFFFFF);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOnError = Color(0xFFFFFFFF);
  static const lightErrorContainer = Color(0xFFFFDAD6);
  static const lightOnErrorContainer = Color(0xFF410002);
  static const lightInversePrimary = Color(0xFFC6B3F7);
  static const lightShadow = Color(0xFF000000);
  static const lightSurface = Color(0xFFFAFAFA);
  static const lightOnSurface = Color(0xFF1C1C1C);
  static const lightAppBarBackground = Color(0xFFEAE0FF);
}

class DarkModeColors {
  static const darkPrimary = Color(0xFFD4BCCF);
  static const darkOnPrimary = Color(0xFF38265C);
  static const darkPrimaryContainer = Color(0xFF4F3D74);
  static const darkOnPrimaryContainer = Color(0xFFEAE0FF);
  static const darkSecondary = Color(0xFFCDC3DC);
  static const darkOnSecondary = Color(0xFF34313F);
  static const darkTertiary = Color(0xFFF0B6C5);
  static const darkOnTertiary = Color(0xFF4A2530);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOnError = Color(0xFF690005);
  static const darkErrorContainer = Color(0xFF93000A);
  static const darkOnErrorContainer = Color(0xFFFFDAD6);
  static const darkInversePrimary = Color(0xFF684F8E);
  static const darkShadow = Color(0xFF000000);
  static const darkSurface = Color(0xFF121212);
  static const darkOnSurface = Color(0xFFE0E0E0);
  static const darkAppBarBackground = Color(0xFF4F3D74);
}

class FontSizes {
  static const double displayLarge = 57.0;
  static const double displayMedium = 45.0;
  static const double displaySmall = 36.0;
  static const double headlineLarge = 32.0;
  static const double headlineMedium = 24.0;
  static const double headlineSmall = 22.0;
  static const double titleLarge = 22.0;
  static const double titleMedium = 18.0;
  static const double titleSmall = 16.0;
  static const double labelLarge = 16.0;
  static const double labelMedium = 14.0;
  static const double labelSmall = 12.0;
  static const double bodyLarge = 16.0;
  static const double bodyMedium = 14.0;
  static const double bodySmall = 12.0;
}

TextTheme _arabicTextTheme() => TextTheme(
      displayLarge: GoogleFonts.cairo(fontSize: FontSizes.displayLarge, fontWeight: FontWeight.w600),
      displayMedium: GoogleFonts.cairo(fontSize: FontSizes.displayMedium, fontWeight: FontWeight.w600),
      displaySmall: GoogleFonts.cairo(fontSize: FontSizes.displaySmall, fontWeight: FontWeight.w600),
      headlineLarge: GoogleFonts.cairo(fontSize: FontSizes.headlineLarge, fontWeight: FontWeight.w600),
      headlineMedium: GoogleFonts.cairo(fontSize: FontSizes.headlineMedium, fontWeight: FontWeight.w600),
      headlineSmall: GoogleFonts.cairo(fontSize: FontSizes.headlineSmall, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.cairo(fontSize: FontSizes.titleLarge, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.cairo(fontSize: FontSizes.titleMedium, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.cairo(fontSize: FontSizes.titleSmall, fontWeight: FontWeight.w600),
      labelLarge: GoogleFonts.cairo(fontSize: FontSizes.labelLarge, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.cairo(fontSize: FontSizes.labelMedium, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.cairo(fontSize: FontSizes.labelSmall, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.cairo(fontSize: FontSizes.bodyLarge, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.cairo(fontSize: FontSizes.bodyMedium, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.cairo(fontSize: FontSizes.bodySmall, fontWeight: FontWeight.w400),
    );

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: LightModeColors.lightPrimary,
        onPrimary: LightModeColors.lightOnPrimary,
        primaryContainer: LightModeColors.lightPrimaryContainer,
        onPrimaryContainer: LightModeColors.lightOnPrimaryContainer,
        secondary: LightModeColors.lightSecondary,
        onSecondary: LightModeColors.lightOnSecondary,
        tertiary: LightModeColors.lightTertiary,
        onTertiary: LightModeColors.lightOnTertiary,
        error: LightModeColors.lightError,
        onError: LightModeColors.lightOnError,
        errorContainer: LightModeColors.lightErrorContainer,
        onErrorContainer: LightModeColors.lightOnErrorContainer,
        inversePrimary: LightModeColors.lightInversePrimary,
        shadow: LightModeColors.lightShadow,
        surface: LightModeColors.lightSurface,
        onSurface: LightModeColors.lightOnSurface,
      ),
      brightness: Brightness.light,
      appBarTheme: const AppBarTheme(
        backgroundColor: LightModeColors.lightAppBarBackground,
        foregroundColor: LightModeColors.lightOnPrimaryContainer,
        elevation: 0,
      ),
      textTheme: _arabicTextTheme(),
    );

ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: DarkModeColors.darkPrimary,
        onPrimary: DarkModeColors.darkOnPrimary,
        primaryContainer: DarkModeColors.darkPrimaryContainer,
        onPrimaryContainer: DarkModeColors.darkOnPrimaryContainer,
        secondary: DarkModeColors.darkSecondary,
        onSecondary: DarkModeColors.darkOnSecondary,
        tertiary: DarkModeColors.darkTertiary,
        onTertiary: DarkModeColors.darkOnTertiary,
        error: DarkModeColors.darkError,
        onError: DarkModeColors.darkOnError,
        errorContainer: DarkModeColors.darkErrorContainer,
        onErrorContainer: DarkModeColors.darkOnErrorContainer,
        inversePrimary: DarkModeColors.darkInversePrimary,
        shadow: DarkModeColors.darkShadow,
        surface: DarkModeColors.darkSurface,
        onSurface: DarkModeColors.darkOnSurface,
      ),
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: DarkModeColors.darkAppBarBackground,
        foregroundColor: DarkModeColors.darkOnPrimaryContainer,
        elevation: 0,
      ),
      textTheme: _arabicTextTheme(),
    );
