import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../services/ad_service.dart';

/// A professional, non-intrusive native ad card that blends naturally
/// into the committee list. Uses AdMob's medium native template styled
/// to match the app's dark theme.
///
/// Behaviour:
///   • Shows nothing while loading (no layout shift)
///   • Fades in smoothly once the ad is ready
///   • Disposes the ad correctly to avoid memory leaks
///   • Only renders on Android / iOS (not on web)
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget>
    with SingleTickerProviderStateMixin {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  // ─────────────────────────── colours ────────────────────────────────────────
  static const Color _cardBg = Color(0xFF1E293B); // darkSurface
  static const Color _primaryColor = Color(0xFF6366F1); // indigo purple
  static const Color _textPrimary = Colors.white;
  static const Color _textSecondary = Color(0xFF94A3B8);
  static const Color _ctaBg = Color(0xFF6366F1);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb || !AdService.adsEnabled) return;

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _isLoaded = true);
          _fadeController.forward();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('NativeAd failed to load: ${error.message}');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        // Medium template gives icon + headline + body + CTA
        templateType: TemplateType.medium,
        mainBackgroundColor: _cardBg,
        cornerRadius: 16,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: _textPrimary,
          backgroundColor: _ctaBg,
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: _textPrimary,
          style: NativeTemplateFontStyle.bold,
          size: 15,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: _textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: _textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 11,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't occupy any space until the ad is ready, and skip on web
    if (kIsWeb || !_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── "Sponsored" label ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'Sponsored',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Ad card ───────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                // TemplateType.medium requires an explicit height in a ListView.
                // AdWidget renders at 0px without bounded vertical constraints.
                height: 320,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                // AdWidget renders the natively-styled ad template
                child: AdWidget(ad: _nativeAd!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
