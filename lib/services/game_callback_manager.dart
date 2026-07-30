// services/game_callback_manager.dart

import 'package:scrabble_P2P/models/game_state.dart';

typedef GameStateCallback = void Function(GameState state);
typedef GameOverCallback = void Function(GameState state);
typedef GameQuitCallback = void Function(String partner);
typedef StatusCallback = void Function(String message);
typedef ErrorCallback = void Function(String message);

class GameCallbackManager {
  static final GameCallbackManager _instance = GameCallbackManager._internal();
  factory GameCallbackManager() => _instance;
  GameCallbackManager._internal();

  // Callbacks actifs (un seul jeu à la fois)
  GameStateCallback? _gameStateCallback;
  GameOverCallback? _gameOverCallback;
  GameQuitCallback? _gameQuitCallback;
  StatusCallback? _statusCallback;
  ErrorCallback? _errorCallback;

  // Propriétaire actuel (pour débogage)
  String _owner = 'none';

  /// Définit les callbacks pour un propriétaire donné.
  /// Si un autre propriétaire était actif, ses callbacks sont remplacés.
  void setCallbacks({
    required String owner,
    GameStateCallback? onGameState,
    GameOverCallback? onGameOver,
    GameQuitCallback? onGameQuit,
    StatusCallback? onStatus,
    ErrorCallback? onError,
  }) {
    if (_owner != owner) {
      print('🔄 GameCallbackManager: $owner prend le contrôle (était $_owner)');
    }
    _owner = owner;
    _gameStateCallback = onGameState;
    _gameOverCallback = onGameOver;
    _gameQuitCallback = onGameQuit;
    _statusCallback = onStatus;
    _errorCallback = onError;
  }

  /// Retire tous les callbacks (désactive le propriétaire actuel)
  void clearCallbacks({String? owner}) {
    if (owner != null && _owner != owner) {
      print(
        '⚠️ Tentative de clear par $owner alors que $_owner est propriétaire',
      );
      return;
    }
    print('🔄 GameCallbackManager: callbacks clearés (propriétaire $_owner)');
    _owner = 'none';
    _gameStateCallback = null;
    _gameOverCallback = null;
    _gameQuitCallback = null;
    _statusCallback = null;
    _errorCallback = null;
  }

  // Getters pour les callbacks (utilisés par RelayNet)
  GameStateCallback? get onGameStateReceived => _gameStateCallback;
  GameOverCallback? get onGameOverReceived => _gameOverCallback;
  GameQuitCallback? get onGameQuitReceived => _gameQuitCallback;
  StatusCallback? get onStatusUpdate => _statusCallback;
  ErrorCallback? get onError => _errorCallback;

  /// Vérifie si un propriétaire est actif
  String get currentOwner => _owner;
}
