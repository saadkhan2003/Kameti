import 'dart:math';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import 'package:committee_app/ui/theme/theme.dart';

/// Shows an animated success overlay with checkmark animation.
/// Call: SuccessAnimation.show(context) — auto-dismisses after 1.5s.
class SuccessAnimation {
  static Future<void> show(BuildContext context, {String? message}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => _SuccessDialog(message: message),
    );
  }
}

class _SuccessDialog extends StatefulWidget {
  final String? message;
  const _SuccessDialog({this.message});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _checkController;
  late final AnimationController _rippleController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOut,
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    );

    // Sequence: scale in → draw check → ripple → dismiss
    _scaleController.forward().then((_) {
      _checkController.forward();
      _rippleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ripple effect
              AnimatedBuilder(
                animation: _rippleAnimation,
                builder: (context, child) {
                  return Container(
                    width: 120 + (60 * _rippleAnimation.value),
                    height: 120 + (60 * _rippleAnimation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.secondaryColor
                            .withOpacity(0.4 * (1 - _rippleAnimation.value)),
                        width: 3,
                      ),
                    ),
                  );
                },
              ),
              // Main circle
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.secondaryColor,
                        AppColors.cFF00C853,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _checkAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _CheckPainter(_checkAnimation.value),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 24),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Material(
                color: Colors.transparent,
                child: Text(
                  widget.message!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = size.center(Offset.zero);

    // Check mark path: two lines
    final start = Offset(center.dx - 18, center.dy + 2);
    final mid = Offset(center.dx - 5, center.dy + 15);
    final end = Offset(center.dx + 20, center.dy - 12);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    if (progress <= 0.5) {
      // First stroke (down)
      final t = progress * 2;
      final x = start.dx + (mid.dx - start.dx) * t;
      final y = start.dy + (mid.dy - start.dy) * t;
      path.lineTo(x, y);
    } else {
      // First stroke complete
      path.lineTo(mid.dx, mid.dy);
      // Second stroke (up)
      final t = (progress - 0.5) * 2;
      final x = mid.dx + (end.dx - mid.dx) * t;
      final y = mid.dy + (end.dy - mid.dy) * t;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Animated loading spinner with pulsing effect — use instead of plain CircularProgressIndicator
class PulsingLoader extends StatefulWidget {
  final double size;
  final Color? color;

  const PulsingLoader({super.key, this.size = 40, this.color});

  @override
  State<PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<PulsingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = widget.color ?? AppTheme.primaryColor;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring
            Transform.scale(
              scale: 0.8 + 0.4 * sin(_controller.value * 2 * pi),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(
                      0.3 * (1 - sin(_controller.value * 2 * pi).abs()),
                    ),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Inner spinning indicator
            SizedBox(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        );
      },
    );
  }
}
