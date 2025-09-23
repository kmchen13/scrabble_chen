import 'dart:io';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/log.dart';
import 'utility.dart';

class GameStorage {
  static const String _boxName = 'gameBox';
  static Box? _box;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      if (debug) {
        print("${logHeader('GameStorage')} initialisé dans ${_box?.path}");
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur init Hive: $e");
    }
  }

  Future<void> save(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = "game_${gameState.gameId}";
      await _box!.put(key, gameState.toMap());
      await _box!.flush();
      if (debug) {
        print("${logHeader('GameStorage')} sauvegardé sous $key");
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur save: $e");
    }
  }

  Future<GameState?> load(String gameId) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = "game_$gameId";
      final data = _box!.get(key);
      if (data != null) {
        final gameState = GameState.fromMap(Map<String, dynamic>.from(data));
        if (debug) {
          print("${logHeader('GameStorage')} restauré sous $key");
        }
        return gameState;
      } else {
        if (debug)
          print("${logHeader('GameStorage')} Aucun GameState sauvegardé");
        return null;
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur load: $e");
      return null;
    }
  }

  Future<void> clear(String gameId) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = "game_$gameId";
      await _box!.delete(key);
      await _box!.flush();
      if (debug) print("${logHeader('GameStorage')} effacé $key");
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur clear: $e");
    }
  }

  Future<void> debugDump() async {
    if (_box == null) {
      print("${logHeader('GameStorage')} debugDump: box == null");
      return;
    }
    print("${logHeader('GameStorage')} debugDump: keys=${_box!.keys.toList()}");
    for (final key in _box!.keys) {
      print("$key => ${_box!.get(key)}");
    }
  }

  /// Retourne la liste des gameId sauvegardés
  Future<List<String>> listSavedGames() async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final keys =
          _box!.keys
              .whereType<String>()
              .where((k) => k.startsWith("game_"))
              .toList();
      return keys.map((k) => k.substring(5)).toList(); // retire "game_"
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur listSavedGames: $e");
      return [];
    }
  }
}

// instance globale
final gameStorage = GameStorage();
