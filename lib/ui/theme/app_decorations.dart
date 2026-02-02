import 'package:flutter/material.dart';
import 'app_colors.dart';

/// App decorations (shadows, borders, radius) - CHANGE THESE TO UPDATE STYLING APP-WIDE
class AppDecorations {
  AppDecorations._();

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════════════
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 28.0;
  static const double radiusRound = 50.0;

  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════
  static List<BoxShadow> get shadowNone => [];

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> shadowPrimary([double opacity = 0.3]) => [
    BoxShadow(
      color: AppColors.primary.withOpacity(opacity),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD DECORATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  static BoxDecoration get cardDark => BoxDecoration(
    color: AppColors.darkCard,
    borderRadius: borderRadiusLg,
  );

  static BoxDecoration get cardLight => BoxDecoration(
    color: AppColors.lightCard,
    borderRadius: borderRadiusLg,
    boxShadow: shadowMd,
  );

  static BoxDecoration get cardWithBorder => BoxDecoration(
    color: AppColors.lightCard,
    borderRadius: borderRadiusLg,
    border: Border.all(color: AppColors.lightBorder),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ICON CONTAINER DECORATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  static BoxDecoration iconContainerPrimary([double opacity = 0.1]) => BoxDecoration(
    color: AppColors.primary.withOpacity(opacity),
    borderRadius: borderRadiusMd,
  );

  static BoxDecoration iconContainerCircle(Color color) => BoxDecoration(
    color: color.withOpacity(0.1),
    shape: BoxShape.circle,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // INPUT DECORATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  static InputDecoration inputDark({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.darkCard,
    border: OutlineInputBorder(
      borderRadius: borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: borderRadiusMd,
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    hintStyle: TextStyle(color: Colors.grey[500]),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING
  // ═══════════════════════════════════════════════════════════════════════════
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
}
