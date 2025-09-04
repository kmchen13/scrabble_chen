import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scrabble_P2P/constants.dart';

import '../models/game_state.dart';

class gameStorage {
  static const String _boxName = 'gameBox';
  static const String _gameKey = 'gameState';

  static Box? _box;

  /// Doit être appelé au démarrage (dans main.dart) **après avoir enregistré les adapters**
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  /// Sauvegarde le GameState courant
  static Future<void> save(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    await _box!.put(_gameKey, gameState.toMap());
    if (debug)
      print(
        "GameState sauvegardé ${gameState.leftLetters}-${gameState.rightLetters}",
      );
  }

  /// Charge un GameState (ou null si absent)
  static GameState? load() {
    if (_box == null) throw Exception("GameStorage not initialized");
    final data = _box!.get(_gameKey);
    if (data == null) return null;
    return GameState.fromMap(Map<String, dynamic>.from(data));
    if (debug)
      print("GameState restauré ${data.leftLetters}-${data.rightLetters}");
  }

  /// Efface la sauvegarde
  static Future<void> clear() async {
    if (_box == null) throw Exception("GameStorage not initialized");
    await _box!.delete(_gameKey);
  }
}
