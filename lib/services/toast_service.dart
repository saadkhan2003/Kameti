import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

enum ToastType { success, error, warning, info }

/// Premium overlay-based toast notification system.
/// Slides in from the top with glassmorphism, animated progress bar,
/// and smooth entrance/exit animations.
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    final overlay = Overlay.of(context);
    final config = _getConfig(type);

    // Auto-set title based on type if not provided
    final effectiveTitle = title ?? config.defaultTitle;

    late OverlayEntry entry;
    final animController = _ToastAnimController();

    entry = OverlayEntry(
      builder: (context) => _AnimatedToast(
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

    // Limit to 3 toasts at a time
    if (_activeToasts.length > 3) {
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
    show(context, message, type: ToastType.error, title: title,
        duration: const Duration(seconds: 4));
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
          icon: Icons.check_circle_rounded,
          accentColor: const Color(0xFF00C853),
          bgGradient: const [Color(0xDD0D1F17), Color(0xDD122A1C)],
          borderColor: const Color(0xFF00C853),
          defaultTitle: 'Success',
        );
      case ToastType.error:
        return _ToastConfig(
          icon: Icons.error_rounded,
          accentColor: const Color(0xFFFF5252),
          bgGradient: const [Color(0xDD2A0F0F), Color(0xDD331414)],
          borderColor: const Color(0xFFFF5252),
          defaultTitle: 'Error',
        );
      case ToastType.warning:
        return _ToastConfig(
          icon: Icons.warning_amber_rounded,
          accentColor: const Color(0xFFFFB74D),
          bgGradient: const [Color(0xDD2A2210), Color(0xDD332B14)],
          borderColor: const Color(0xFFFFB74D),
          defaultTitle: 'Warning',
        );
      case ToastType.info:
        return _ToastConfig(
          icon: Icons.info_rounded,
          accentColor: AppTheme.primaryColor,
          bgGradient: const [Color(0xDD0F1629), Color(0xDD141D33)],
          borderColor: AppTheme.primaryColor,
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

    // Slide + fade + scale animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      ),
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
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child!,
              ),
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
          if (_dragOffset > 30) {
            _dismiss();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        onTap: _dismiss,
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.config.bgGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.config.borderColor.withAlpha(80),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.config.accentColor.withAlpha(40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(100),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          // Animated icon with glow
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: widget.config.accentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: widget.config.accentColor.withAlpha(60),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              widget.config.icon,
                              color: widget.config.accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Title + Message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: widget.config.accentColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(220),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    height: 1.3,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close button
                          GestureDetector(
                            onTap: _dismiss,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.white.withAlpha(120),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Animated progress bar
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                            child: LinearProgressIndicator(
                              value: 1 - _progressController.value,
                              backgroundColor: Colors.white.withAlpha(10),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.config.accentColor.withAlpha(180),
                              ),
                              minHeight: 3,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
