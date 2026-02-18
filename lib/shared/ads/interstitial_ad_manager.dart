import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdManager {
  InterstitialAdManager._();

  static final InterstitialAdManager instance = InterstitialAdManager._();

  // Show at most after every N completed actions and with cooldown.
  static const int _actionsBetweenAds = 3;
  static const Duration _cooldown = Duration(minutes: 3);

  static const bool _useTestAds =
      bool.fromEnvironment('USE_TEST_ADS', defaultValue: true);

  static const String _androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';

  // Replace these with your production Ad Unit IDs before release.
  static const String _androidProdInterstitialId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String _iosProdInterstitialId =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  InterstitialAd? _interstitial;
  bool _initialized = false;
  bool _isLoading = false;
  bool _isShowing = false;
  int _completedActions = 0;
  DateTime? _lastShownAt;

  bool get _isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String? get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _useTestAds
          ? _androidTestInterstitialId
          : _androidProdInterstitialId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _useTestAds ? _iosTestInterstitialId : _iosProdInterstitialId;
    }
    return null;
  }

  Future<void> initialize() async {
    if (!_isSupportedPlatform || _initialized) return;
    _initialized = true;
    _loadInterstitial();
  }

  void recordActionAndMaybeShow({required String placement}) {
    if (!_isSupportedPlatform) return;

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != AppLifecycleState.resumed) return;

    _completedActions += 1;
    if (kDebugMode) {
      debugPrint(
        '[AdMob] action="$placement", count=$_completedActions, ready=${_interstitial != null}',
      );
    }

    if (!_isEligibleToShow) {
      if (_interstitial == null) _loadInterstitial();
      return;
    }

    _showInterstitial();
  }

  bool get _isEligibleToShow {
    if (_isShowing) return false;
    if (_interstitial == null) return false;
    if (_completedActions < _actionsBetweenAds) return false;
    final lastShown = _lastShownAt;
    if (lastShown == null) return true;
    return DateTime.now().difference(lastShown) >= _cooldown;
  }

  void _showInterstitial() {
    final ad = _interstitial;
    if (ad == null) return;

    _interstitial = null;
    _isShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowing = false;
        _completedActions = 0;
        _lastShownAt = DateTime.now();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowing = false;
        _loadInterstitial();
      },
    );

    ad.show();
  }

  void _loadInterstitial() {
    if (!_isSupportedPlatform || _isLoading || _interstitial != null) return;

    final adUnitId = _adUnitId;
    if (adUnitId == null || adUnitId.contains('xxxxxxxx')) return;

    _isLoading = true;

    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _interstitial = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('[AdMob] Interstitial load failed: $error');
          }
        },
      ),
    );
  }

  void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}
