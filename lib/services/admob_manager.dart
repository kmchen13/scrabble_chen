import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gestionnaire des bannières AdMob
class AdMobManager {
  // Instance unique (Singleton)
  static final AdMobManager _instance = AdMobManager._internal();
  factory AdMobManager() => _instance;
  AdMobManager._internal();

  // Bannières
  BannerAd? _bannerAd1;
  BannerAd? _bannerAd2;

  // États
  bool _isAdLoaded1 = false;
  bool _isAdLoaded2 = false;
  AdSize? _adSize1;
  AdSize? _adSize2;

  // Getters
  bool get isAdLoaded1 => _isAdLoaded1;
  bool get isAdLoaded2 => _isAdLoaded2;
  AdSize? get adSize1 => _adSize1;
  AdSize? get adSize2 => _adSize2;
  BannerAd? get bannerAd1 => _bannerAd1;
  BannerAd? get bannerAd2 => _bannerAd2;

  // Callbacks pour notifier le UI
  VoidCallback? _onAdLoaded;
  VoidCallback? _onAdFailed;

  void setCallbacks({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    _onAdLoaded = onLoaded;
    _onAdFailed = onFailed;
  }

  /// Charger la bannière 1
  Future<void> loadBanner1(BuildContext context) async {
    if (_bannerAd1 != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final String adUnitId =
        Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/9214589741'
            : 'ca-app-pub-3940256099942544/2435281174';

    try {
      final AdSize? adSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate(),
          );

      if (adSize == null) return;
      _adSize1 = adSize;

      _bannerAd1 = BannerAd(
        adUnitId: adUnitId,
        size: adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isAdLoaded1 = true;
            _onAdLoaded?.call();
            print('✅ Bannière 1 chargée');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd1 = null;
            _isAdLoaded1 = false;
            _onAdFailed?.call();
            print('❌ Bannière 1: $error');
          },
        ),
      )..load();
    } catch (e) {
      print('⚠️ Erreur bannière 1: $e');
    }
  }

  /// Charger la bannière 2
  Future<void> loadBanner2(BuildContext context) async {
    if (_bannerAd2 != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    // En production, utilisez un ID différent
    final String adUnitId =
        Platform.isAndroid
            ? 'ca-app-pub-3940256099942544/9214589741'
            : 'ca-app-pub-3940256099942544/2435281174';

    try {
      final AdSize? adSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate(),
          );

      if (adSize == null) return;
      _adSize2 = adSize;

      _bannerAd2 = BannerAd(
        adUnitId: adUnitId,
        size: adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isAdLoaded2 = true;
            _onAdLoaded?.call();
            print('✅ Bannière 2 chargée');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd2 = null;
            _isAdLoaded2 = false;
            _onAdFailed?.call();
            print('❌ Bannière 2: $error');
          },
        ),
      )..load();
    } catch (e) {
      print('⚠️ Erreur bannière 2: $e');
    }
  }

  /// Charger les deux bannières
  Future<void> loadBothBanners(BuildContext context) async {
    await Future.wait([loadBanner1(context), loadBanner2(context)]);
  }

  /// Libérer les ressources
  void dispose() {
    _bannerAd1?.dispose();
    _bannerAd2?.dispose();
    _bannerAd1 = null;
    _bannerAd2 = null;
    _isAdLoaded1 = false;
    _isAdLoaded2 = false;
    _adSize1 = null;
    _adSize2 = null;
  }

  /// Vérifier si les deux bannières sont chargées
  bool get areBothLoaded => _isAdLoaded1 && _isAdLoaded2;
}
