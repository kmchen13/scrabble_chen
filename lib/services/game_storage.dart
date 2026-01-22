import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/utility.dart';

String gameKey(String a, String b) {
  final sorted = [a, b]..sort();
  return 'game_${sorted[0]}_${sorted[1]}';
}

class GameStorage {
  static const String _boxName = 'gameBox';
  static Box? _box;

  static String buildKey(String partner) => "game_$partner";

  Future<void> init() async {
    if (_box != null && _box!.isOpen) {
      if (debug) {
        print("${logHeader('GameStorage')} déjà initialisé");
      }
      return;
    }
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

  /// Retourne true si aucune partie n'est sauvegardée
  Future<bool> get isEmpty async {
    final savedGames = await listSavedGames();
    return savedGames.isEmpty;
  }

  Future<void> save(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = buildKey(gameState.partnerFrom(settings.localUserName));
      await _box!.put(key, gameState.toMap());
      await _box!.flush();
      // await gameStorage.debugDump();
      if (debug) {
        print(
          "${logHeader('GameStorage')} game.hash(${gameState.hashCode} sauvegardé sous $key",
        );
      }
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur save: $e");
    }
  }

  Future<GameState?> load(String partner) async {
    await gameStorage.debugDump();
    if (partner.isEmpty) return null; // safeguard
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = GameStorage.buildKey(partner);
      final data = _box!.get(key);
      if (data == null) return null;
      if (data is! Map) {
        print("${logHeader('GameStorage')} Donnée invalide pour $key");
        return null;
      }
      final gameState = GameState.fromMap(Map<String, dynamic>.from(data));
      if (debug) print("${logHeader('GameStorage')} restauré sous $key");
      return gameState;
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur load: $e");
      return null;
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

  /// Retourne la liste des partner sauvegardés
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

  /// Supprime une entrée par clé complète (ex: "game_partnerName")
  Future<void> delete(String partner) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    final key = buildKey(partner);
    try {
      await _box!.delete(key);
      await _box!.flush();
      if (debug) print("${logHeader('GameStorage')} supprimé $key");
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur delete: $e");
    }
  }

  ///Supprime toutes les parties sauvegardées
  Future<void> deleteAllGames() async {
    if (_box == null) throw Exception("GameStorage not initialized");

    final gameKeys = _box!.keys.whereType<String>().where(
      (k) => k.startsWith("game_"),
    );

    for (final key in gameKeys) {
      await _box!.delete(key);
    }
    await _box!.flush();

    if (debug) {
      print("${logHeader('GameStorage')} toutes les parties supprimées");
    }
  }

  /// Ferme la box proprement
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
      if (debug) {
        print("${logHeader('GameStorage')} box fermée proprement");
      }
    }
  }
}

// instance globale
final gameStorage = GameStorage();
