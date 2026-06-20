import 'package:flutter/widgets.dart';

class AppLifecycle with WidgetsBindingObserver {
  static bool isForeground = true;

  void start() {
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    isForeground = state == AppLifecycleState.resumed;
  }
}
