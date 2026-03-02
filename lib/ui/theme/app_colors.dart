import 'package:flutter/material.dart';

/// App color palette - CHANGE THESE TO UPDATE COLORS APP-WIDE
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIMARY COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color primary = Color(0xFF6366F1);       // Indigo purple
  static const Color primaryDark = Color(0xFF4F46E5);   // Darker purple
  static const Color primaryLight = Color(0xFF818CF8);  // Lighter purple

  // ═══════════════════════════════════════════════════════════════════════════
  // SECONDARY / ACCENT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color secondary = Color(0xFF10B981);     // Emerald green
  static const Color accent = Color(0xFFFF6B4A);        // Coral orange

  // ═══════════════════════════════════════════════════════════════════════════
  // STATUS COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color success = Color(0xFF10B981);       // Green
  static const Color error = Color(0xFFEF4444);         // Red
  static const Color warning = Color(0xFFF59E0B);       // Orange
  static const Color info = Color(0xFF3B82F6);          // Blue

  // ═══════════════════════════════════════════════════════════════════════════
  // DARK THEME BACKGROUNDS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color darkBg = Color(0xFF0F172A);        // Main background
  static const Color darkSurface = Color(0xFF1E293B);   // Elevated surface
  static const Color darkCard = Color(0xFF334155);      // Card background

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME BACKGROUNDS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color lightBg = Color(0xFFFFFFFF);       // Main background
  static const Color lightSurface = Color(0xFFF8F9FA); // Elevated surface
  static const Color lightCard = Color(0xFFFFFFFF);     // Card background
  static const Color lightBorder = Color(0xFFE5E7EB);   // Border color

  // ═══════════════════════════════════════════════════════════════════════════
  // PASTEL ACCENTS (for stats, badges, highlights)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color pastelLavender = Color(0xFFF3E8FF);  // Light purple
  static const Color pastelMint = Color(0xFFD1FAE5);      // Light green
  static const Color pastelYellow = Color(0xFFFEF3C7);    // Light yellow
  static const Color pastelPink = Color(0xFFFCE7F3);      // Light pink
  static const Color pastelBlue = Color(0xFFDBEAFE);      // Light blue

  // ═══════════════════════════════════════════════════════════════════════════
  // TEXT COLORS
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color textDark = Color(0xFF1A1A1A);        // Primary text (light theme)
  static const Color textMedium = Color(0xFF6B7280);      // Secondary text
  static const Color textLight = Color(0xFF9CA3AF);       // Tertiary/hint text
  static const Color textOnPrimary = Colors.white;        // Text on primary color

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
