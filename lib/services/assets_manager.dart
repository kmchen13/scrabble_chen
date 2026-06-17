import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../constants.dart';

class AssetManager {
  static bool get _isDesktop =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  static String _desktopAssetPath(String assetPath) {
    final exeDir = p.dirname(Platform.resolvedExecutable);

    return p.join(exeDir, 'data', 'flutter_assets', assetPath);
  }

  static Future<String> loadString(String assetPath) async {
    if (!_isDesktop) {
      return rootBundle.loadString(assetPath);
    }

    final path = _desktopAssetPath(assetPath);

    if (debug) {
      print('[AssetManager] loadString $path');
    }

    final file = File(path);

    if (!file.existsSync()) {
      throw Exception('Asset absent: $path');
    }

    return file.readAsString();
  }

  static Future<List<int>> loadBytes(String assetPath) async {
    if (!_isDesktop) {
      final data = await rootBundle.load(assetPath);

      return data.buffer.asUint8List();
    }

    final path = _desktopAssetPath(assetPath);

    if (debug) {
      print('[AssetManager] loadBytes $path');
    }

    final file = File(path);

    if (!file.existsSync()) {
      throw Exception('Asset absent: $path');
    }

    return file.readAsBytes();
  }

  static String desktopPath(String assetPath) {
    return _desktopAssetPath(assetPath);
  }
}
