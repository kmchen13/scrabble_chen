import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:scrabble_P2P/services/admob_manager.dart';

/// Bannière unique
class SingleBannerWidget extends StatelessWidget {
  final AdMobManager manager;

  const SingleBannerWidget({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    if (!manager.isAdLoaded1 || manager.adSize1 == null) {
      return Container(height: 0, color: Colors.grey[900]);
    }

    return Container(
      height: manager.adSize1!.height.toDouble(),
      color: Colors.grey[900],
      child: AdWidget(ad: manager.bannerAd1!),
    );
  }
}

/// Deux bannières côte à côte
class DoubleBannerWidget extends StatelessWidget {
  final AdMobManager manager;
  final bool isLargeScreen;

  const DoubleBannerWidget({
    super.key,
    required this.manager,
    required this.isLargeScreen,
  });

  @override
  Widget build(BuildContext context) {
    if (!manager.isAdLoaded1 || manager.adSize1 == null) {
      return Container(height: 0, color: Colors.grey[900]);
    }

    if (!isLargeScreen || !manager.isAdLoaded2 || manager.adSize2 == null) {
      return Container(
        height: manager.adSize1!.height.toDouble(),
        color: Colors.grey[900],
        child: AdWidget(ad: manager.bannerAd1!),
      );
    }

    return Container(
      height: manager.adSize1!.height.toDouble(),
      color: Colors.grey[900],
      child: Row(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[900],
              child: AdWidget(ad: manager.bannerAd1!),
            ),
          ),
          VerticalDivider(width: 1, color: Colors.grey[700]),
          Expanded(
            child: Container(
              color: Colors.grey[900],
              child: AdWidget(ad: manager.bannerAd2!),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ AppBar avec bannière - IMPLÉMENTE PreferredSizeWidget
class AdBannerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final AdMobManager manager;
  final String title;
  final double titleHeight;
  final double fontSize;
  final bool isLargeScreen;

  const AdBannerAppBar({
    super.key,
    required this.manager,
    required this.title,
    required this.titleHeight,
    required this.fontSize,
    required this.isLargeScreen,
  });

  double get _bannerHeight =>
      manager.isAdLoaded1 && manager.adSize1 != null
          ? manager.adSize1!.height.toDouble()
          : 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_bannerHeight > 0)
            DoubleBannerWidget(manager: manager, isLargeScreen: isLargeScreen),
          AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: titleHeight,
            title: Text(title, style: TextStyle(fontSize: fontSize)),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(titleHeight + _bannerHeight);
}
