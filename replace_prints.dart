import 'dart:io';
import 'package:flutter/foundation.dart';

void main() {
  final rootDir = Directory.current;
  final dartFiles = rootDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in dartFiles) {
    final content = file.readAsStringSync();
    if (content.contains('debugPrint(')) {
      final newContent = content.replaceAllMapped(
        RegExp(r'\bprint\('),
        (match) => 'debugPrint(',
      );
      file.writeAsStringSync(newContent);
      debugPrint('Modified ${file.path}');
    }
  }

  debugPrint('Replacement done.');
}
