import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ IMPORT
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:scrabble_P2P/services/admob_manager.dart';

class SingleBannerWidget extends StatelessWidget {
  final AdMobManager manager;

  const SingleBannerWidget({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    if (!manager.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    if (!manager.isAdLoaded || manager.adSize == null) {
      return const SizedBox.shrink();
    }

    final height = manager.adSize!.height.toDouble();
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      color: Colors.grey[900],
      child: AdWidget(ad: manager.bannerAd!),
    );
  }
}

class AdBannerOverlay extends StatelessWidget {
  final AdMobManager manager;

  const AdBannerOverlay({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    if (!manager.isSupportedPlatform) {
      return const SizedBox.shrink();
    }

    if (!manager.isAdLoaded || manager.adSize == null) {
      return const SizedBox.shrink();
    }

    final height = manager.adSize!.height.toDouble();
    if (height <= 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: height,
          color: Colors.grey[900],
          child: AdWidget(ad: manager.bannerAd!),
        ),
      ),
    );
  }
}

class AdBannerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AdMobManager manager;
  final String title;
  final double titleHeight;
  final double fontSize;

  const AdBannerAppBar({
    super.key,
    required this.manager,
    required this.title,
    required this.titleHeight,
    required this.fontSize,
  });

  double get _bannerHeight {
    if (!manager.isSupportedPlatform) return 0;
    return manager.bannerHeight;
  }

  @override
  Widget build(BuildContext context) {
    if (!manager.isSupportedPlatform) {
      return AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: titleHeight,
        title: Text(title, style: TextStyle(fontSize: fontSize)),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
      );
    }

    return SafeArea(
      bottom: false,
      child: Container(
        color: Theme.of(context).primaryColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_bannerHeight > 0)
              Container(
                height: _bannerHeight,
                color: Colors.grey[900],
                child: SingleBannerWidget(manager: manager),
              ),
            AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: titleHeight,
              title: Text(title, style: TextStyle(fontSize: fontSize)),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(titleHeight + _bannerHeight);
}
