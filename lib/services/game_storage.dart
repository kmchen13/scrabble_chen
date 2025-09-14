import 'dart:io';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'utility.dart';

class GameStorage {
  static const String _boxName = 'gameBox';
  static const String _gameKey = 'gameState';

  static Box? _box;

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }

      Directory dir = await getApplicationDocumentsDirectory();
      final gameBoxDir = Directory('${dir.path}/$_boxName');
      if (debug) {
        print("${logHeader('GameStorage')} initialisé dans ${_box?.path}");
      }
      if (!await gameBoxDir.exists()) {
        await gameBoxDir.create(recursive: true);
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur init Hive: $e");
    }
  }

  Future<void> save(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      await _box!.put(_gameKey, gameState.toMap());
      await _box!.flush();
      if (debug) {
        print(
          "${logHeader('GameStorage')} sauvegardé ${gameState.leftLetters}-${gameState.rightLetters}",
        );
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur save: $e");
    }
  }

  Future<GameState?> load() async {
    if (debug) {
      print("${logHeader('GameStorage')} load() appelé");
    }
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final data = _box!.get(_gameKey);
      if (data != null) {
        final gameState = GameState.fromMap(Map<String, dynamic>.from(data));
        if (debug) {
          print(
            "${logHeader('GameStorage')} restauré ${gameState.leftLetters}-${gameState.rightLetters}",
          );
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

  Future<void> clear() async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      await _box!.delete(_gameKey);
      await _box!.flush();
      if (debug) print("${logHeader('GameStorage')} effacé");
      debugDump();
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur clear: $e");
    }
  }

  Future<void> debugDump() async {
    if (_box == null) {
      print("${logHeader('GameStorage')} debugDump: box == null");
      return;
    }
    print("${logHeader('GameStorage')} debugDump: box.path=${_box?.path}");
    print("${logHeader('GameStorage')} debugDump: keys=${_box!.keys.toList()}");
    print(
      "${logHeader('GameStorage')} debugDump: value=${_box!.get(_gameKey)}",
    );
  }
}

// instance globale
final gameStorage = GameStorage();
