import 'package:flutter/foundation.dart';

/// Centralised ad configuration.
/// - Debug / profile builds → Google's official test IDs (never charges real money)
/// - Release builds         → Live production ad unit IDs
class AdService {
  AdService._();

  static const Duration fullScreenAdCooldown = Duration(minutes: 1);
  static DateTime? _lastFullScreenAdShownAt;

  // ─── App IDs ────────────────────────────────────────────────────────────────
  static const String _productionAppId =
      'ca-app-pub-1709708368201318~9324084262';

  // ─── Native Ad Unit IDs ─────────────────────────────────────────────────────
  /// Google's official test native ad unit (Android).
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  /// Live native ad unit for the main committee list screen.
  static const String _productionNativeAdUnitId =
      'ca-app-pub-1709708368201318/6595212675';

  // ─── Banner Ad Unit IDs ─────────────────────────────────────────────────────
  /// Google's official test banner ad unit (Android).
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Live banner ad unit for the member view screen.
  static const String _productionBannerAdUnitId =
      'ca-app-pub-1709708368201318/4460838075';

  // ─── App Open Ad Unit IDs ───────────────────────────────────────────────────
  /// Google's official test app open ad unit (Android).
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/9257395921';

  /// Live app open ad unit.
  static const String _productionAppOpenAdUnitId =
      'ca-app-pub-1709708368201318/1246207712';

  // ─── Public getters ─────────────────────────────────────────────────────────

  /// Returns the correct App ID for the current build flavour.
  static String get appId => _productionAppId;

  /// Returns the correct native ad unit ID:
  /// • [kReleaseMode] = true  → production unit
  /// • [kReleaseMode] = false → test unit (debug / profile)
  static String get nativeAdUnitId =>
      kReleaseMode ? _productionNativeAdUnitId : _testNativeAdUnitId;

  /// Returns the correct banner ad unit ID:
  /// • [kReleaseMode] = true  → production unit
  /// • [kReleaseMode] = false → test unit (debug / profile)
  static String get bannerAdUnitId =>
      kReleaseMode ? _productionBannerAdUnitId : _testBannerAdUnitId;

  /// Returns the correct app open ad unit ID:
  /// • [kReleaseMode] = true  → production unit
  /// • [kReleaseMode] = false → test unit (debug / profile)
  static String get appOpenAdUnitId =>
      kReleaseMode ? _productionAppOpenAdUnitId : _testAppOpenAdUnitId;

  /// Whether ads should be shown in the current environment.
  /// You can add extra logic here (e.g. hide for premium users).
  static bool get adsEnabled => true;

  /// Returns true if enough time has passed since the last full-screen ad show.
  static bool canShowFullScreenAd({DateTime? now}) {
    final currentTime = now ?? DateTime.now();

    if (!adsEnabled) return false;
    if (_lastFullScreenAdShownAt == null) return true;

    final elapsed = currentTime.difference(_lastFullScreenAdShownAt!);
    return elapsed >= fullScreenAdCooldown;
  }

  /// Marks that a full-screen ad was shown now.
  /// Call this from `onAdShowedFullScreenContent` callbacks.
  static void markFullScreenAdShown({DateTime? now}) {
    _lastFullScreenAdShownAt = now ?? DateTime.now();
  }

  /// Remaining cooldown before another full-screen ad can be shown.
  /// Returns [Duration.zero] when no cooldown is active.
  static Duration fullScreenAdCooldownRemaining({DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    if (_lastFullScreenAdShownAt == null) return Duration.zero;

    final elapsed = currentTime.difference(_lastFullScreenAdShownAt!);
    final remaining = fullScreenAdCooldown - elapsed;

    if (remaining.isNegative || remaining == Duration.zero) {
      return Duration.zero;
    }

    return remaining;
  }
}
