import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppBarStyles {
  AppBarStyles._();

  static AppBar standard({
    required String title,
    Widget? leading,
    List<Widget>? actions,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}

class AppButtonStyles {
  AppButtonStyles._();

  static ButtonStyle outlinedPrimary() {
    return OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColors.primary),
      foregroundColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.textSecondary,
      disabledBackgroundColor: AppColors.mutedSurface,
    ).copyWith(
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: AppColors.borderMuted);
        }
        return const BorderSide(color: AppColors.primary);
      }),
    );
  }

  static ButtonStyle outlinedError() {
    return OutlinedButton.styleFrom(
      side: const BorderSide(color: AppColors.error),
      foregroundColor: AppColors.error,
      backgroundColor: AppColors.surface,
      disabledForegroundColor: AppColors.textSecondary,
      disabledBackgroundColor: AppColors.mutedSurface,
    ).copyWith(
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: AppColors.borderMuted);
        }
        return const BorderSide(color: AppColors.error);
      }),
    );
  }

  static ButtonStyle elevatedSuccess() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.success,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.borderMuted,
      disabledForegroundColor: AppColors.textSecondary,
    );
  }

  static ButtonStyle elevatedWarning() {
    return ElevatedButton.styleFrom(
      backgroundColor: AppColors.warning,
      foregroundColor: Colors.white,
      disabledBackgroundColor: AppColors.borderMuted,
      disabledForegroundColor: AppColors.textSecondary,
    );
  }
}
