import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Gestionnaire des bannières AdMob - Version simplifiée (1 bannière)
class AdMobManager {
  static final AdMobManager _instance = AdMobManager._internal();
  factory AdMobManager() => _instance;
  AdMobManager._internal();

  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  AdSize? _adSize;

  // ✅ Vérification de la plateforme supportée
  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    if (Platform.isWindows) return false;
    if (Platform.isLinux) return false;
    if (Platform.isMacOS) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isAdLoaded => _isAdLoaded;
  AdSize? get adSize => _adSize;
  BannerAd? get bannerAd => _bannerAd;

  VoidCallback? _onAdLoaded;
  VoidCallback? _onAdFailed;

  void setCallbacks({VoidCallback? onLoaded, VoidCallback? onFailed}) {
    _onAdLoaded = onLoaded;
    _onAdFailed = onFailed;
  }

  String get adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/9214589741';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2435281174';
    }
    return '';
  }

  /// Charger une seule bannière adaptative
  Future<void> loadBanner(BuildContext context) async {
    if (_bannerAd != null) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      final AdSize? adSize =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            MediaQuery.of(context).size.width.truncate(),
          );

      if (adSize == null) return;
      _adSize = adSize;

      _bannerAd = BannerAd(
        adUnitId: adUnitId,
        size: adSize,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            _isAdLoaded = true;
            _onAdLoaded?.call();
            print('✅ Bannière chargée ${adSize.width}x${adSize.height}');
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd = null;
            _isAdLoaded = false;
            _onAdFailed?.call();
            print('❌ Bannière: $error');
          },
        ),
      )..load();
    } catch (e) {
      print('⚠️ Erreur bannière: $e');
    }
  }

  /// Hauteur de la bannière (0 si non chargée)
  double get bannerHeight {
    if (_isAdLoaded && _adSize != null) {
      return _adSize!.height.toDouble();
    }
    return 0;
  }

  /// Libérer les ressources
  void dispose() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _adSize = null;
  }
}
