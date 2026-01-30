import 'package:committee_app/core/theme/app_colors.dart';
import 'package:committee_app/core/theme/app_decorations.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable confirm dialog
/// 
/// Example usage:
/// ```dart
/// final result = await showConfirmDialog(
///   context: context,
///   title: 'Delete Item?',
///   message: 'This action cannot be undone.',
///   confirmText: 'Delete',
///   cancelText: 'Cancel',
///   isDestructive: true,
/// );
/// if (result == true) { ... }
/// ```
Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmText = 'Confirm',
  String cancelText = 'Cancel',
  bool isDestructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => ConfirmDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDestructive: isDestructive,
    ),
  );
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDestructive;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.borderRadiusLg,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(color: Colors.grey[400]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            cancelText,
            style: GoogleFonts.inter(color: Colors.grey[400]),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// Info dialog for showing messages
Future<void> showInfoDialog({
  required BuildContext context,
  required String title,
  required String message,
  String buttonText = 'OK',
}) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppDecorations.borderRadiusLg,
      ),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(color: Colors.grey[400]),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(buttonText),
        ),
      ],
    ),
  );
}

/// Loading dialog
void showLoadingDialog(BuildContext context, {String? message}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: AppDecorations.borderRadiusLg,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message,
                style: GoogleFonts.inter(color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void hideLoadingDialog(BuildContext context) {
  Navigator.of(context).pop();
}
