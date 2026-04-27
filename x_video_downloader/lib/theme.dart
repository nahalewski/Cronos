import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color onSurfaceVariant = Color(0xFF414755);
  static const Color primaryContainer = Color(0xFF0070EB);
  static const Color surfaceTint = Color(0xFF005BC1);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color onTertiaryFixed = Color(0xFF351000);
  static const Color outlineVariant = Color(0xFFC1C6D7);
  static const Color onPrimaryContainer = Color(0xFFFEFCFF);
  static const Color surfaceContainerHighest = Color(0xFFE2E2E4);
  static const Color surfaceBright = Color(0xFFF9F9FB);
  static const Color onSurface = Color(0xFF1A1C1D);
  static const Color surfaceContainerLow = Color(0xFFF3F3F5);
  static const Color error = Color(0xFFBA1A1A);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE2E2E4);
  static const Color onSecondaryContainer = Color(0xFF626267);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF9F9FB);
  static const Color onBackground = Color(0xFF1A1C1D);
  static const Color onTertiaryFixedVariant = Color(0xFF7C2E00);
  static const Color inverseSurface = Color(0xFF2F3132);
  static const Color inverseOnSurface = Color(0xFFF0F0F2);
  static const Color onPrimaryFixed = Color(0xFF001A41);
  static const Color inversePrimary = Color(0xFFADC6FF);
  static const Color outline = Color(0xFF717786);
  static const Color onSecondaryFixedVariant = Color(0xFF46464B);
  static const Color tertiaryContainer = Color(0xFFC64F00);
  static const Color primary = Color(0xFF0058BC);
  static const Color primaryFixedDim = Color(0xFFADC6FF);
  static const Color tertiary = Color(0xFF9E3D00);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFD9DADF);
  static const Color secondaryContainer = Color(0xFFE0DFE4);
  static const Color secondary = Color(0xFF5D5E63);
  static const Color surfaceContainer = Color(0xFFEEEFF0);
  static const Color tertiaryFixed = Color(0xFFFFDBCC);
  static const Color onTertiaryContainer = Color(0xFFFFFBFB);
  static const Color surfaceContainerHigh = Color(0xFFE8E8EA);
  static const Color secondaryFixed = Color(0xFFE3E2E7);
  static const Color primaryFixed = Color(0xFFD8E2FF);
  static const Color onPrimaryFixedVariant = Color(0xFF004493);
  static const Color secondaryFixedDim = Color(0xFFC6C6CB);
  static const Color onSecondaryFixed = Color(0xFF1A1B1F);
  static const Color tertiaryFixedDim = Color(0xFFF5B595);
  static const Color surface = Color(0xFFF9F9FB);
}

// Cache the text theme to avoid rebuilding on every frame
TextTheme? _cachedTextTheme;

ThemeData buildVenturaSlateTheme() {
  // Performance: Use cached text theme to avoid Google Fonts network call on every build
  _cachedTextTheme ??= GoogleFonts.interTextTheme();
  final baseTextTheme = _cachedTextTheme!;

  return ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryContainer,
      secondary: AppColors.secondary,
      secondaryContainer: AppColors.secondaryContainer,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.onPrimary,
      onSecondary: AppColors.onSecondary,
      onSurface: AppColors.onSurface,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      inversePrimary: AppColors.inversePrimary,
      inverseSurface: AppColors.inverseSurface,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      onErrorContainer: AppColors.onErrorContainer,
      onTertiary: AppColors.onTertiary,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceTint: AppColors.surfaceTint,
    ),
    textTheme: baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w800,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontFamily: GoogleFonts.inter().fontFamily,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
