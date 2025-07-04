import '../models/game_state.dart';

class GameStorageService {
  static final GameStorageService _instance = GameStorageService._internal();
  factory GameStorageService() => _instance;

  GameStorageService._internal();

  late GameState _gameState;

  void saveGameState(GameState state) {
    _gameState = state;
  }

  GameState getGameState() {
    return _gameState;
  }

  final Map<String, dynamic> _storage = {};

  void saveData(String key, dynamic value) {
    _storage[key] = value;
  }

  dynamic getData(String key) {
    return _storage[key];
  }

  void clear() {
    _storage.clear();
  }
}
