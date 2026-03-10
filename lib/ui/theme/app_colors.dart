import 'package:flutter/material.dart';

/// App color palette - CHANGE THESE TO UPDATE COLORS APP-WIDE
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF3347A8);
  static const Color primaryDark = Color(0xFF25348A);
  static const Color primaryLight = Color(0xFF4F46E5);

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY / ACCENT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color secondary = Color(0xFF2563EB);
  static const Color accent = Color(0xFF7C4DFF);

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME BACKGROUNDS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color darkBg = Color(0xFF0F172A); // Main background
  static const Color darkSurface = Color(0xFF1E293B); // Elevated surface
  static const Color darkCard = Color(0xFF334155); // Card background

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME BACKGROUNDS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color lightBg = Color(0xFFF7F8FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFDCE4F7);

  // ═══════════════════════════════════════════════════════════════════════════
  // PASTEL ACCENTS (for stats, badges, highlights)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color pastelLavender = Color(0xFFF3E8FF); // Light purple
  static const Color pastelMint = Color(0xFFD1FAE5); // Light green
  static const Color pastelYellow = Color(0xFFFEF3C7); // Light yellow
  static const Color pastelPink = Color(0xFFFCE7F3); // Light pink
  static const Color pastelBlue = Color(0xFFDBEAFE); // Light blue

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;

  // Common semantic aliases used by screens
  static const Color bg = lightBg;
  static const Color bgAlt = Color(0xFFEEF1F8);
  static const Color surface = lightSurface;
  static const Color border = lightBorder;
  static const Color borderMuted = Color(0xFFE2E8F0);
  static const Color mutedSurface = Color(0xFFF1F5F9);
  static const Color softPrimary = Color(0xFFEAF0FF);
  static const Color textPrimary = textDark;
  static const Color textSecondary = textMedium;

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-GENERATED HEX TOKENS (compatibility only)
  static const Color cFF00BCD4 = Color(0xFF00BCD4);
  static const Color cFF00C853 = Color(0xFF00C853);
  static const Color cFF047857 = Color(0xFF047857);
  static const Color cFF06B6D4 = Color(0xFF06B6D4);
  static const Color cFF1E1E22 = Color(0xFF1E1E22);
  static const Color cFF1E1E2E = Color(0xFF1E1E2E);
  static const Color cFF2A2A2E = Color(0xFF2A2A2E);
  static const Color cFF34D399 = Color(0xFF34D399);
  static const Color cFF3A3A40 = Color(0xFF3A3A40);
  static const Color cFF448AFF = Color(0xFF448AFF);
  static const Color cFF475569 = Color(0xFF475569);
  static const Color cFF5B6FD6 = Color(0xFF5B6FD6);
  static const Color cFF6C63FF = Color(0xFF6C63FF);
  static const Color cFF9A3412 = Color(0xFF9A3412);
  static const Color cFFA2ADBF = Color(0xFFA2ADBF);
  static const Color cFFB0B8C9 = Color(0xFFB0B8C9);
  static const Color cFFB2BCD0 = Color(0xFFB2BCD0);
  static const Color cFFB45309 = Color(0xFFB45309);
  static const Color cFFB8C3D8 = Color(0xFFB8C3D8);
  static const Color cFFB91C1C = Color(0xFFB91C1C);
  static const Color cFFBEE9D0 = Color(0xFFBEE9D0);
  static const Color cFFC9D4EE = Color(0xFFC9D4EE);
  static const Color cFFC9D8FF = Color(0xFFC9D8FF);
  static const Color cFFCBD5E1 = Color(0xFFCBD5E1);
  static const Color cFFCCDAFF = Color(0xFFCCDAFF);
  static const Color cFFCCE6D8 = Color(0xFFCCE6D8);
  static const Color cFFCFD9EF = Color(0xFFCFD9EF);
  static const Color cFFCFDBFF = Color(0xFFCFDBFF);
  static const Color cFFCFE8D9 = Color(0xFFCFE8D9);
  static const Color cFFD0D9EE = Color(0xFFD0D9EE);
  static const Color cFFD1DCF7 = Color(0xFFD1DCF7);
  static const Color cFFD2DDF8 = Color(0xFFD2DDF8);
  static const Color cFFD3DDEF = Color(0xFFD3DDEF);
  static const Color cFFD7DEEE = Color(0xFFD7DEEE);
  static const Color cFFD7DFEE = Color(0xFFD7DFEE);
  static const Color cFFD7E0F2 = Color(0xFFD7E0F2);
  static const Color cFFD7E1F5 = Color(0xFFD7E1F5);
  static const Color cFFD7E1FB = Color(0xFFD7E1FB);
  static const Color cFFD7E3FF = Color(0xFFD7E3FF);
  static const Color cFFD8E2F8 = Color(0xFFD8E2F8);
  static const Color cFFD9E3F6 = Color(0xFFD9E3F6);
  static const Color cFFDCE5F6 = Color(0xFFDCE5F6);
  static const Color cFFDDE3F1 = Color(0xFFDDE3F1);
  static const Color cFFDDE5F5 = Color(0xFFDDE5F5);
  static const Color cFFDDE5F6 = Color(0xFFDDE5F6);
  static const Color cFFDDE6F7 = Color(0xFFDDE6F7);
  static const Color cFFDDE6FA = Color(0xFFDDE6FA);
  static const Color cFFE3EAF9 = Color(0xFFE3EAF9);
  static const Color cFFE4EAF7 = Color(0xFFE4EAF7);
  static const Color cFFE4ECFF = Color(0xFFE4ECFF);
  static const Color cFFE5EAF6 = Color(0xFFE5EAF6);
  static const Color cFFE5ECF9 = Color(0xFFE5ECF9);
  static const Color cFFE6ECF8 = Color(0xFFE6ECF8);
  static const Color cFFE8EEFA = Color(0xFFE8EEFA);
  static const Color cFFE8EEFF = Color(0xFFE8EEFF);
  static const Color cFFE9EEFC = Color(0xFFE9EEFC);
  static const Color cFFEAF8F0 = Color(0xFFEAF8F0);
  static const Color cFFECFDF3 = Color(0xFFECFDF3);
  static const Color cFFEDF2FF = Color(0xFFEDF2FF);
  static const Color cFFEEF2FA = Color(0xFFEEF2FA);
  static const Color cFFEFF4FF = Color(0xFFEFF4FF);
  static const Color cFFF0F3FA = Color(0xFFF0F3FA);
  static const Color cFFF1F5FF = Color(0xFFF1F5FF);
  static const Color cFFF2C9CF = Color(0xFFF2C9CF);
  static const Color cFFF3F6FF = Color(0xFFF3F6FF);
  static const Color cFFF3FBF7 = Color(0xFFF3FBF7);
  static const Color cFFF59E0B = Color(0xFFF59E0B);
  static const Color cFFF5D7AE = Color(0xFFF5D7AE);
  static const Color cFFF6C8C8 = Color(0xFFF6C8C8);
  static const Color cFFF7F9FF = Color(0xFFF7F9FF);
  static const Color cFFF7FAFF = Color(0xFFF7FAFF);
  static const Color cFFF8FAFF = Color(0xFFF8FAFF);
  static const Color cFFFDEAEA = Color(0xFFFDEAEA);
  static const Color cFFFECACA = Color(0xFFFECACA);
  static const Color cFFFED7AA = Color(0xFFFED7AA);
  static const Color cFFFEF2F2 = Color(0xFFFEF2F2);
  static const Color cFFFEF4F4 = Color(0xFFFEF4F4);
  static const Color cFFFFB74D = Color(0xFFFFB74D);
  static const Color cFFFFF1F2 = Color(0xFFFFF1F2);
  static const Color cFFFFF2E4 = Color(0xFFFFF2E4);
  static const Color cFFFFF7ED = Color(0xFFFFF7ED);
  static const Color cFFFFF8F0 = Color(0xFFFFF8F0);

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [darkBg, darkSurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
