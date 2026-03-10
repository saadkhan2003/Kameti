import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:committee_app/ui/theme/theme.dart';

/// Handles in-app review logic with "reviewed" and "maybe later" persistence.
///
/// Flow:
/// 1. First triggers after [_launchThreshold] app launches.
/// 2. If user taps "Maybe Later", re-prompts after [_reminderDays] days.
/// 3. Once the user rates OR dismisses via "Not now" (second dismissal),
///    the prompt is permanently suppressed.
class ReviewService {
  static const String _settingsBox = 'app_settings';
  static const String _keyReviewGiven = 'review_given';
  static const String _keyLaterDate = 'review_later_date';
  static const String _keyLaunchCount = 'review_launch_count';

  /// Number of app launches before the first review prompt.
  static const int _launchThreshold = 5;

  /// Days to wait after tapping "Maybe Later" before re-prompting.
  static const int _reminderDays = 7;

  static final ReviewService _instance = ReviewService._();
  ReviewService._();
  factory ReviewService() => _instance;

  final _inAppReview = InAppReview.instance;

  Future<Box> get _box async {
    if (!Hive.isBoxOpen(_settingsBox)) {
      await Hive.openBox(_settingsBox);
    }
    return Hive.box(_settingsBox);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Increment the launch counter. Call once per cold start.
  Future<void> recordAppLaunch() async {
    final box = await _box;
    final count = (box.get(_keyLaunchCount, defaultValue: 0) as int) + 1;
    await box.put(_keyLaunchCount, count);
  }

  /// Returns true if the review dialog should be presented right now.
  Future<bool> shouldShowReview() async {
    final box = await _box;

    // Never prompt if user has already reviewed (or permanently dismissed).
    final given = box.get(_keyReviewGiven, defaultValue: false) as bool;
    if (given) return false;

    final laterDateStr = box.get(_keyLaterDate) as String?;

    if (laterDateStr != null) {
      // Re-prompt only after [_reminderDays] have passed.
      final laterDate = DateTime.tryParse(laterDateStr);
      if (laterDate == null) return false;
      final daysSince = DateTime.now().difference(laterDate).inDays;
      return daysSince >= _reminderDays;
    }

    // First-time: show after reaching launch threshold.
    final launches = box.get(_keyLaunchCount, defaultValue: 0) as int;
    return launches >= _launchThreshold;
  }

  /// Show the two-step review flow (custom dialog → native sheet).
  ///
  /// Call this at a meaningful moment (e.g. dashboard loaded, payment saved).
  Future<void> maybeShowReview(BuildContext context) async {
    if (!context.mounted) return;
    final should = await shouldShowReview();
    if (!should) return;
    if (!context.mounted) return;

    _showCustomDialog(context);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _showCustomDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: AppColors.cFF1E1E2E,
            title: const Column(
              children: [
                Text('⭐', style: TextStyle(fontSize: 40)),
                SizedBox(height: 8),
                Text(
                  'Enjoying Kameti?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Your feedback helps us improve the app for everyone. '
              'It only takes a few seconds!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 20,
            ),
            actions: [
              // Rate Now
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _markReviewGiven();
                    await _requestNativeReview();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.cFF6C63FF,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Rate Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Maybe Later
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _markMaybeLater();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Maybe Later',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ),
              ),
              // Not Now (permanent dismiss)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _markReviewGiven(); // suppress permanently
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _requestNativeReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      }
    } catch (_) {
      // Native review is OS-controlled — silently swallow all errors.
    }
  }

  Future<void> _markReviewGiven() async {
    final box = await _box;
    await box.put(_keyReviewGiven, true);
  }

  Future<void> _markMaybeLater() async {
    final box = await _box;
    await box.put(_keyLaterDate, DateTime.now().toIso8601String());
  }
}
