import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_theme.dart';
import 'package:committee_app/ui/theme/theme.dart';

enum ToastType { success, error, warning, info }

/// Overlay-based toast notification system.
/// Clean, minimal, and consistent across the app.
class ToastService {
  static final List<_ToastEntry> _activeToasts = [];

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Hide any existing SnackBars (legacy cleanup)
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final config = _getConfig(type);

    // Auto-set title based on type if not provided
    final effectiveTitle = title ?? config.defaultTitle;

    late OverlayEntry entry;
    final animController = _ToastAnimController();

    entry = OverlayEntry(
      builder:
          (context) => _AnimatedToast(
            message: message,
            title: effectiveTitle,
            config: config,
            duration: duration,
            animController: animController,
            onDismiss: () {
              entry.remove();
              _activeToasts.removeWhere((e) => e.entry == entry);
              _repositionToasts();
            },
            index: _activeToasts.length,
          ),
    );

    _activeToasts.add(_ToastEntry(entry: entry, controller: animController));
    overlay.insert(entry);

    // Keep one toast visible at a time for a cleaner UX
    if (_activeToasts.length > 1) {
      final oldest = _activeToasts.removeAt(0);
      oldest.controller.dismiss();
    }
  }

  static void _repositionToasts() {
    // Toasts auto-reposition via their index in build
  }

  static void success(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.success, title: title);
  }

  static void error(BuildContext context, String message, {String? title}) {
    show(
      context,
      message,
      type: ToastType.error,
      title: title,
      duration: const Duration(seconds: 4),
    );
  }

  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.warning, title: title);
  }

  static void info(BuildContext context, String message, {String? title}) {
    show(context, message, type: ToastType.info, title: title);
  }

  static _ToastConfig _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return _ToastConfig(
          icon: AppIcons.paid,
          accentColor: AppColors.success,
          bgGradient: const [AppColors.cFFF3FBF7, AppColors.cFFEAF8F0],
          borderColor: AppColors.cFFBEE9D0,
          defaultTitle: 'Success',
        );
      case ToastType.error:
        return _ToastConfig(
          icon: AppIcons.error_rounded,
          accentColor: AppColors.error,
          bgGradient: const [AppColors.cFFFEF4F4, AppColors.cFFFDEAEA],
          borderColor: AppColors.cFFF6C8C8,
          defaultTitle: 'Error',
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: AppIcons.warning,
          accentColor: AppColors.warning,
          bgGradient: const [AppColors.cFFFFF8F0, AppColors.cFFFFF2E4],
          borderColor: AppColors.cFFF5D7AE,
          defaultTitle: 'Warning',
        );
      case ToastType.info:
        return _ToastConfig(
          icon: AppIcons.info_rounded,
          accentColor: AppTheme.primaryColor,
          bgGradient: const [AppColors.cFFF3F6FF, AppColors.softPrimary],
          borderColor: AppColors.cFFCCDAFF,
          defaultTitle: 'Info',
        );
    }
  }
}

class _ToastEntry {
  final OverlayEntry entry;
  final _ToastAnimController controller;

  _ToastEntry({required this.entry, required this.controller});
}

class _ToastAnimController {
  VoidCallback? _dismissCallback;

  void dismiss() {
    _dismissCallback?.call();
  }

  void setDismissCallback(VoidCallback callback) {
    _dismissCallback = callback;
  }
}

class _ToastConfig {
  final IconData icon;
  final Color accentColor;
  final List<Color> bgGradient;
  final Color borderColor;
  final String defaultTitle;

  _ToastConfig({
    required this.icon,
    required this.accentColor,
    required this.bgGradient,
    required this.borderColor,
    required this.defaultTitle,
  });
}

class _AnimatedToast extends StatefulWidget {
  final String message;
  final String title;
  final _ToastConfig config;
  final Duration duration;
  final VoidCallback onDismiss;
  final _ToastAnimController animController;
  final int index;

  const _AnimatedToast({
    required this.message,
    required this.title,
    required this.config,
    required this.duration,
    required this.onDismiss,
    required this.animController,
    required this.index,
  });

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();

    // Slide + fade + subtle scale animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 260),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    // Progress bar animation (countdown)
    _progressController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // Start entrance animation
    _slideController.forward();
    _progressController.forward();

    // Schedule dismiss
    _dismissTimer = Timer(widget.duration, _dismiss);

    // Register dismiss callback
    widget.animController.setDismissCallback(_dismiss);
  }

  void _dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();

    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _slideController,
      builder: (context, child) {
        return Positioned(
          bottom: bottomPadding + 16 - _dragOffset,
          left: 16,
          right: 16,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(scale: _scaleAnimation, child: child!),
            ),
          ),
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            setState(() => _dragOffset += details.delta.dy);
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffset > 24) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        onTap: _dismiss,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.config.bgGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.config.borderColor, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBg.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: widget.config.accentColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.config.icon,
                          color: widget.config.accentColor,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.inter(
                                color: AppColors.darkBg,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: GoogleFonts.inter(
                                color: AppColors.cFF475569,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _dismiss,
                        icon: const Icon(
                          AppIcons.close,
                          color: AppColors.textMedium,
                          size: 18,
                        ),
                        splashRadius: 18,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      child: LinearProgressIndicator(
                        value: 1 - _progressController.value,
                        backgroundColor: AppColors.borderMuted,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.config.accentColor,
                        ),
                        minHeight: 2,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
