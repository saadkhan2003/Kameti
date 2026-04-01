import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Manages the App Open Ad lifecycle:
///   • Loads a fresh ad as soon as possible (cold start + after each dismiss)
///   • Shows on cold start (triggered from SplashScreen after init)
///   • Shows when app returns from background (triggered by lifecycle observer)
///   • Enforces a 4-hour cooldown between background-resume shows
///   • Can be suppressed so ads never show over the biometric lock screen
///
/// Usage:
///   // In main():
///   await AppOpenAdService.instance.initialize();
///
///   // In SplashScreen (cold start):
///   AppOpenAdService.instance.showColdStartAd();
///
///   // In AppLifecycleState.resumed:
///   AppOpenAdService.instance.showResumeAd();
///
///   // When showing / hiding lock screen:
///   AppOpenAdService.instance.setSuppressed(true);
///   AppOpenAdService.instance.setSuppressed(false);
class AppOpenAdService {
  AppOpenAdService._();
  static final AppOpenAdService instance = AppOpenAdService._();

  // ── State ──────────────────────────────────────────────────────────────────
  AppOpenAd? _ad;
  bool _isLoadInProgress = false;
  bool _isShowingAd = false;
  bool _suppressed = false;
  DateTime? _lastShowTime;
  bool _coldStartAdShown = false;

  /// Minimum gap between background-resume shows (AdMob recommends ≥ 4 hours).
  static const Duration _resumeCooldown = Duration(hours: 4);

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call once after [MobileAds.instance.initialize()].
  /// Begins loading the first ad in the background.
  Future<void> initialize() async {
    if (kIsWeb || !AdService.adsEnabled) return;
    await _loadAd();
  }

  /// Show the ad on cold start (first app launch).
  /// Safe to call multiple times — only fires once per session.
  void showColdStartAd() {
    if (_coldStartAdShown) return;
    _coldStartAdShown = true;
    _tryShow();
  }

  /// Show the ad when the app returns from background.
  /// Respects the [_resumeCooldown] — won't spam users.
  void showResumeAd() {
    // Skip if not enough time has passed since last show
    if (_lastShowTime != null &&
        DateTime.now().difference(_lastShowTime!) < _resumeCooldown) {
      return;
    }
    _tryShow();
  }

  /// Prevent ads from showing (e.g. when biometric lock is displayed).
  void setSuppressed(bool value) => _suppressed = value;

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _loadAd() async {
    if (_isLoadInProgress || _ad != null) return;
    _isLoadInProgress = true;

    await AppOpenAd.load(
      adUnitId: AdService.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AppOpenAd loaded');
          _ad = ad;
          _isLoadInProgress = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: ${error.message}');
          _isLoadInProgress = false;
          // Retry after a short delay to avoid tight loops on network errors
          Future.delayed(const Duration(seconds: 30), _loadAd);
        },
      ),
    );
  }

  void _tryShow() {
    if (_suppressed) return;
    if (_isShowingAd) return;
    if (!AdService.canShowFullScreenAd()) return;
    if (_ad == null) {
      // Ad not ready — start loading for next opportunity
      _loadAd();
      return;
    }

    _isShowingAd = true;

    _ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        debugPrint('AppOpenAd showed');
        _lastShowTime = DateTime.now();
        AdService.markFullScreenAdShown();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AppOpenAd dismissed');
        _isShowingAd = false;
        ad.dispose();
        _ad = null;
        _loadAd(); // Pre-load next ad immediately after dismiss
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AppOpenAd failed to show: ${error.message}');
        _isShowingAd = false;
        ad.dispose();
        _ad = null;
        _loadAd();
      },
    );

    _ad!.show();
  }
}
