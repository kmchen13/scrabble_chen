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

      // 🔥 Afficher la liste AVANT la sauvegarde
      if (debug) {
        // 🔥 Afficher la pile d'appels
        print("${logHeader('GameStorage.save')} Appelé depuis:");
        print(StackTrace.current);
        final before = await listSavedGames();
        print("${logHeader('GameStorage.save')} AVANT: $before");
      }

      await delete(partner); // Supprime l'ancienne version (normale ou non lue)
      await _box!.put(storageKey, gameState.toMap());
      await _box!.flush();

      // 🔥 Afficher la liste APRÈS la sauvegarde
      if (debug) {
        final after = await listSavedGames();
        print("${logHeader('GameStorage.save')} APRÈS: $after");
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

      // 🔥 Essayer d'abord avec "*" (non lu)
      String? actualKey;
      Map? data;

      if (_box!.containsKey(unreadKey)) {
        actualKey = unreadKey;
        data = _box!.get(actualKey);
        if (debug) {
          print("${logHeader('GameStorage')} chargé depuis clé non lue");
        }
      }
      // Sinon utiliser la clé normale
      else if (_box!.containsKey(key)) {
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

      // 🔥 Si c'était une clé non lue, la transformer en clé normale
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

      // 🔥 Retourner les clés telles quelles (avec "*" si présent)
      return keys
          .map((k) => k.substring(5))
          .toList(); // retire "game_" mais garde "*"
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
