import 'package:hive/hive.dart';
import 'game_state.dart';

class GameStorage {
  static const String boxName = "scrabbleGame";

  static Future<void> saveGame(GameState state) async {
    final box = await Hive.openBox<String>(boxName);
    await box.put('current', state.toJson());
  }

  static Future<GameState?> loadGame() async {
    final box = await Hive.openBox<String>(boxName);
    final json = box.get('current');
    if (json == null) return null;
    return GameState.fromJson(json);
  }

  static Future<void> clearGame() async {
    final box = await Hive.openBox<String>(boxName);
    await box.delete('current');
  }
}
