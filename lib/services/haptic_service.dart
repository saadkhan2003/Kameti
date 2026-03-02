import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Centralized haptic feedback service for tactile responses.
/// Automatically skips haptics on web platform.
class HapticService {
  HapticService._();

  /// Light tap — for button presses, list taps
  static void lightTap() {
    if (kIsWeb) return;
    HapticFeedback.lightImpact();
  }

  /// Medium tap — for toggle switches, selection changes
  static void mediumTap() {
    if (kIsWeb) return;
    HapticFeedback.mediumImpact();
  }

  /// Heavy tap — for important actions (delete, archive)
  static void heavyTap() {
    if (kIsWeb) return;
    HapticFeedback.heavyImpact();
  }

  /// Success vibration — for completed actions
  static void success() {
    if (kIsWeb) return;
    HapticFeedback.mediumImpact();
  }

  /// Error vibration — for failures, validation errors
  static void error() {
    if (kIsWeb) return;
    HapticFeedback.heavyImpact();
  }

  /// Selection tick — for picker changes, toggle taps
  static void selectionTick() {
    if (kIsWeb) return;
    HapticFeedback.selectionClick();
  }
}
