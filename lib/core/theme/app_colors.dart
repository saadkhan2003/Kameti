import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF60A5FA);

  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFFF6B4A);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  static const Color darkBg = Color(0xFFFFFFFF);
  static const Color darkSurface = Color(0xFFF8FAFC);
  static const Color darkCard = Color(0xFFFFFFFF);

  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color pastelLavender = Color(0xFFF3E8FF);
  static const Color pastelMint = Color(0xFFD1FAE5);
  static const Color pastelYellow = Color(0xFFFEF3C7);
  static const Color pastelPink = Color(0xFFFCE7F3);
  static const Color pastelBlue = Color(0xFFDBEAFE);

  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);
  static const Color textOnPrimary = Colors.white;

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
