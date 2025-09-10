import 'dart:io';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrabble_P2P/constants.dart';

import '../models/game_state.dart';
import 'utility.dart';

class gameStorage {
  static const String _boxName = 'gameBox';
  static const String _gameKey = 'gameState';

  static Box? _box;

  /// Doit être appelé au démarrage (dans main.dart) **après avoir enregistré les adapters**
  static Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }

      Directory dir = await getApplicationDocumentsDirectory();
      final gameBoxDir = Directory('${dir.path}/$_boxName');
      if (debug) {
        print(
          "${logHeader('GameStorage')}  gameStorage initialisé dans ${_box?.path}",
        );
      }
      if (!await gameBoxDir.exists()) {
        await gameBoxDir.create(recursive: true);
      }
    } catch (e) {
      print(
        "${logHeader('GameStorage')}  Erreur lors de l'initialisation de Hive: $e",
      );
    }
  }

  /// Sauvegarde le GameState courant
  static Future<void> save(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      print(
        "${logHeader('GameStorage')} save() called — stack: ${StackTrace.current.toString().split('\n').take(5).join(' | ')}",
      );
      await _box!.put(_gameKey, gameState.toMap());
      await _box!.flush();
      if (debug) {
        print(
          "${logHeader('GameStorage')} GameState sauvegardé ${gameState.leftLetters}-${gameState.rightLetters}",
        );
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur lors de la sauvegarde: $e");
    }
  }

  /// Charge un GameState (ou null si absent)
  static GameState? load() {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final data = _box!.get(_gameKey);
      if (data != null) {
        final gameState = GameState.fromMap(Map<String, dynamic>.from(data));
        if (debug) {
          print(
            "${logHeader('GameStorage')} GameState restauré "
            "${gameState.leftLetters}-${gameState.rightLetters}",
          );
        }
        return gameState;
      } else {
        if (debug)
          print("${logHeader('GameStorage')}  Aucun GameState sauvegardé");
        return null;
      }
    } catch (e) {
      print(
        "${logHeader('GameStorage')}  Erreur lors du chargement du GameState: $e",
      );
      return null;
    }
  }

  /// Efface la sauvegarde
  static Future<void> clear() async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      await _box!.delete(_gameKey);
      await _box!.flush(); // force la suppression sur disque
      if (debug) print("${logHeader('GameStorage')}  GameState effacé");
      debugDump();
    } catch (e) {
      print(
        "${logHeader('GameStorage')}  Erreur lors de l’effacement du GameState: $e",
      );
    }
  }

  static Future<void> debugDump() async {
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
