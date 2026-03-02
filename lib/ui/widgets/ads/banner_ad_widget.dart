import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../services/ad_service.dart';

/// An anchored adaptive banner ad widget.
///
/// AdMob recommends the anchored adaptive banner format because it
/// automatically selects an optimal height for each device / orientation.
///
/// Placement rules followed:
///   • Anchored at the bottom of the screen (Scaffold.bottomNavigationBar).
///   • Width = full screen width minus horizontal safe-area insets.
///   • Uses [AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize] with a
///     fallback to the classic 320×50 [AdSize.banner] if the adaptive call
///     returns null (very old SDK versions).
///
/// Build behaviour:
///   • Renders [SizedBox.shrink] while the ad is loading → zero layout shift.
///   • Fades in smoothly once the ad is ready.
///   • Skipped entirely on web ([kIsWeb]).
///   • Properly disposes [BannerAd] to prevent memory leaks.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget>
    with SingleTickerProviderStateMixin {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _loadCalled = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
  }

  // didChangeDependencies is the correct place to access MediaQuery for the
  // first time, before the first build, and it fires before initState's
  // post-frame callbacks.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadCalled) {
      _loadCalled = true;
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (kIsWeb || !AdService.adsEnabled) return;

    // Subtract horizontal safe-area padding so the ad never overflows on
    // notched / edge-to-edge devices.
    final mq = MediaQuery.of(context);
    final availableWidth = (mq.size.width - mq.padding.horizontal).truncate();

    // Request the optimal adaptive height for the current orientation and width.
    AdSize? adaptiveSize;
    try {
      adaptiveSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            availableWidth,
          );
    } catch (_) {
      // Silently fall through to the standard banner.
    }

    // Fall back to the classic 320×50 banner if adaptive size is unavailable.
    _adSize = adaptiveSize ?? AdSize.banner;

    if (!mounted) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: _adSize!,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
          _fadeController.forward();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: ${error.message}');
          ad.dispose();
          // Keep _isLoaded = false → widget renders as SizedBox.shrink.
        },
        onAdOpened: (_) => debugPrint('BannerAd opened.'),
        onAdClosed: (_) => debugPrint('BannerAd closed.'),
      ),
    )..load();

    // Trigger a rebuild so _adSize is available for sizing the container.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show: web, not loaded yet, or ad / size unavailable.
    if (kIsWeb || !_isLoaded || _bannerAd == null || _adSize == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      // SafeArea ensures the ad is not hidden behind phone gesture bars.
      child: SafeArea(
        top: false,
        child: Container(
          alignment: Alignment.center,
          // Constrain to exactly the ad's reported dimensions.
          width: _adSize!.width.toDouble(),
          height: _adSize!.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
