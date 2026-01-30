import 'package:committee_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App typography styles - CHANGE THESE TO UPDATE TEXT STYLES APP-WIDE
class AppTypography {
  AppTypography._();

  // ═══════════════════════════════════════════════════════════════════════════
  // FONT FAMILY
  // ═══════════════════════════════════════════════════════════════════════════
  static String get fontFamily => GoogleFonts.inter().fontFamily!;

  // ═══════════════════════════════════════════════════════════════════════════
  // DISPLAY / HEADINGS
  // ═══════════════════════════════════════════════════════════════════════════
  static TextStyle displayLarge = GoogleFonts.inter(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle headlineLarge = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle headlineMedium = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle headlineSmall = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // BODY TEXT
  // ═══════════════════════════════════════════════════════════════════════════
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: Colors.white,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.grey,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Colors.grey,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // LABELS / BUTTONS
  // ═══════════════════════════════════════════════════════════════════════════
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.grey,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPECIAL STYLES
  // ═══════════════════════════════════════════════════════════════════════════
  static TextStyle appBarTitle = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle cardTitle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle cardSubtitle = GoogleFonts.inter(
    fontSize: 13,
    color: Colors.grey[400],
  );

  static TextStyle statValue = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static TextStyle statLabel = GoogleFonts.inter(
    fontSize: 12,
    color: Colors.grey[400],
  );

  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle linkText = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );
}
