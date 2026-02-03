import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppLog {
  static final AppLog _instance = AppLog._internal();
  factory AppLog() => _instance;
  AppLog._internal();

  static const int maxLines = 1000;

  final List<String> _buffer = [];
  File? _file;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/scrabble.log');

    if (await _file!.exists()) {
      final existing = await _file!.readAsLines();
      if (existing.length > maxLines) {
        _buffer.addAll(existing.sublist(existing.length - maxLines));
      } else {
        _buffer.addAll(existing);
      }
    }
  }

  void log(String tag, String message) {
    final line = '${DateTime.now().toIso8601String()} | $tag | $message';

    _buffer.add(line);
    if (_buffer.length > maxLines) {
      _buffer.removeAt(0);
    }

    // réécrit le fichier entier → garantit la taille max
    _file?.writeAsStringSync(_buffer.join('\n') + '\n', mode: FileMode.write);
  }

  Future<File?> getFile() async => _file;

  List<String> get buffer => List.unmodifiable(_buffer);

  Future<void> clear() async {
    _buffer.clear();
    await _file?.writeAsString('');
  }
}
