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

Map<String, dynamic> deepCastMap(Map map) {
  return map.map((key, value) {
    if (value is Map) {
      return MapEntry(key.toString(), deepCastMap(value));
    } else if (value is List) {
      return MapEntry(
        key.toString(),
        value.map((e) {
          if (e is Map) return deepCastMap(e);
          return e;
        }).toList(),
      );
    } else {
      return MapEntry(key.toString(), value);
    }
  });
}

class GameStorage {
  static const String _boxName = 'gameBox';
  static Box? _box;

  // 🔥 Suffixe pour marquer les parties non lues
  static const String _unreadSuffix = '*';

  // 🔥 Préfixe pour les états en attente d'envoi réseau
  static const String _pendingPrefix = 'pending_';

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

  /// Sauvegarde l'état du jeu pour un partenaire donné
  /// Si markAsUnread est true, la clé sera suffixée avec "*"
  Future<void> save(GameState gameState, {bool markAsUnread = false}) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final partner = gameState.partnerFrom(settings.localUser);
      final key = buildKey(partner);

      final unreadKey = "$key$_unreadSuffix";
      final storageKey = markAsUnread ? unreadKey : key;

      await delete(partner); // Supprime l'ancienne version (normale ou non lue)
      await _box!.put(storageKey, gameState.toMap());
      await _box!.flush();

      if (debug) {
        print(
          "${logHeader('GameStorage.save')} game.hash(${gameState.hashCode}) sauvegardé sous $storageKey${markAsUnread ? ' (non lu)' : ''}",
        );
      }
    } catch (e) {
      print("${logHeader('GameStorage.save')} Erreur save: $e");
    }
  }

  Future<GameState?> load(String partner) async {
    if (partner.isEmpty) return null;
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final key = buildKey(partner);
      final unreadKey = "$key$_unreadSuffix";

      String? actualKey;
      Map? data;

      if (_box!.containsKey(unreadKey)) {
        actualKey = unreadKey;
        data = _box!.get(actualKey);
        if (debug) {
          print("${logHeader('GameStorage')} chargé depuis clé non lue");
        }
      } else if (_box!.containsKey(key)) {
        actualKey = key;
        data = _box!.get(actualKey);
        if (debug) {
          print("${logHeader('GameStorage')} chargé depuis clé normale");
        }
      } else {
        return null;
      }

      if (data == null) return null;
      if (data is! Map) {
        print("${logHeader('GameStorage')} Donnée invalide pour $actualKey");
        return null;
      }

      final map = deepCastMap(data);
      final gameState = GameState.fromMap(map);

      if (actualKey == unreadKey) {
        await _box!.delete(unreadKey);
        await _box!.put(key, map);
        await _box!.flush();

        if (debug) {
          print(
            "${logHeader('GameStorage')} clé non lue transformée en clé normale",
          );
        }
      }

      if (debug) {
        print("${logHeader('GameStorage')} restauré sous $key");
      }
      return gameState;
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur load: $e");
      return null;
    }
  }

  // ==================== Méthodes dédiées aux états en attente ====================
  static String buildPendingKey(
    GameState gameState, {
    String prefix = 'pending',
  }) {
    final partner = gameState.partnerFrom(settings.localUser);
    return '${prefix}_$partner';
  }

  // ========== GameState (pending) ==========
  Future<void> savePending(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    final key = buildPendingKey(gameState, prefix: 'pending');
    await _box!.put(key, gameState.toMap());
    await _box!.flush();
  }

  // ⭐ Load tous les GameState en attente (globaux)
  Future<List<GameState>> loadAllPending() async {
    if (_box == null) return [];
    final keys = _box!.keys.whereType<String>().where(
      (k) => k.startsWith('pending_') && !k.startsWith('pending_gameover_'),
    );
    final list = <GameState>[];
    for (final key in keys) {
      final data = _box!.get(key);
      if (data is Map) {
        final map = deepCastMap(data);
        list.add(GameState.fromMap(map));
      }
    }
    return list;
  }

  // ⭐ Suppression ciblée (par partenaire)
  Future<void> deletePending(GameState gameState) async {
    if (_box == null) return;
    final key = buildPendingKey(gameState, prefix: 'pending');
    await _box!.delete(key);
    await _box!.flush();
  }

  // ⭐ Suppression globale de tous les GameState en attente
  Future<void> deleteAllPending() async {
    if (_box == null) return;
    final keys = _box!.keys.whereType<String>().where(
      (k) => k.startsWith('pending_') && !k.startsWith('pending_gameover_'),
    );
    for (final key in keys) {
      await _box!.delete(key);
    }
    await _box!.flush();
  }

  // ========== GameOver (pending) ==========
  Future<void> savePendingGameOver(GameState gameState) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    final key = buildPendingKey(gameState, prefix: 'pending_gameover');
    await _box!.put(key, gameState.toMap());
    await _box!.flush();
  }

  // ⭐ Load tous les GameOver en attente (globaux)
  Future<List<GameState>> loadAllPendingGameOver() async {
    if (_box == null) return [];
    final keys = _box!.keys.whereType<String>().where(
      (k) => k.startsWith('pending_gameover_'),
    );
    final list = <GameState>[];
    for (final key in keys) {
      final data = _box!.get(key);
      if (data is Map) {
        final map = deepCastMap(data);
        list.add(GameState.fromMap(map));
      }
    }
    return list;
  }

  // ⭐ Suppression ciblée (par partenaire)
  Future<void> deletePendingGameOver(GameState gameState) async {
    if (_box == null) return;
    final key = buildPendingKey(gameState, prefix: 'pending_gameover');
    await _box!.delete(key);
    await _box!.flush();
  }

  // ⭐ Suppression globale de tous les GameOver en attente
  Future<void> deleteAllPendingGameOver() async {
    if (_box == null) return;
    final keys = _box!.keys.whereType<String>().where(
      (k) => k.startsWith('pending_gameover_'),
    );
    for (final key in keys) {
      await _box!.delete(key);
    }
    await _box!.flush();
  }

  // ==================== Fin méthodes pending ====================

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

  /// Retourne la liste des clés complètes (avec "*" si présent)
  Future<List<String>> listSavedGames() async {
    if (_box == null) throw Exception("GameStorage not initialized");
    try {
      final keys =
          _box!.keys
              .whereType<String>()
              .where((k) => k.startsWith("game_"))
              .toList();

      return keys.map((k) => k.substring(5)).toList();
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur listSavedGames: $e");
      return [];
    }
  }

  /// 🔥 Vérifie si une partie est non lue
  Future<bool> isUnread(String partner) async {
    if (_box == null) return false;
    final key = buildKey(partner);
    final unreadKey = "$key$_unreadSuffix";
    return _box!.containsKey(unreadKey);
  }

  /// 🔥 Marque une partie comme lue (supprime le "*" si présent)
  Future<void> markAsRead(String partner) async {
    if (_box == null) return;
    final key = buildKey(partner);
    final unreadKey = "$key$_unreadSuffix";

    if (_box!.containsKey(unreadKey)) {
      final data = _box!.get(unreadKey);
      await _box!.delete(unreadKey);
      if (data != null) {
        await _box!.put(key, data);
        await _box!.flush();
        if (debug) {
          print("${logHeader('GameStorage')} $partner marqué comme lu");
        }
      }
    }
  }

  /// Supprime une entrée (supprime aussi la version non lue si présente)
  Future<void> delete(String partner) async {
    if (_box == null) throw Exception("GameStorage not initialized");
    final key = buildKey(partner);
    final unreadKey = "$key$_unreadSuffix";
    try {
      await _box!.delete(key);
      await _box!.delete(unreadKey);
      await _box!.flush();
      if (debug)
        print(
          "${logHeader('GameStorage')} supprimé $key (et sa version non lue)",
        );
    } catch (e) {
      print("${logHeader('GameStorage')} Erreur delete: $e");
    }
  }

  /// Supprime toutes les parties sauvegardées
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
