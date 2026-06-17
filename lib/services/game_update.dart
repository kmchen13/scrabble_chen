import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import '../constants.dart';

typedef ApplyIncomingState =
    Future<void> Function(GameState newState, {required bool updateUI});

typedef GameStateCallback = void Function(GameState state);
typedef StringCallback = void Function(String message);
typedef VoidCallback = void Function();

class GameUpdateHandler {
  final ScrabbleNet net;
  final ApplyIncomingState applyIncomingState;
  final bool Function() isMounted;
  final GameState Function() getCurrentGame;

  // 🔥 Callbacks UI (injectés par l’écran)
  final GameStateCallback? onBackgroundMove;
  final GameStateCallback? onGameOver;
  final StringCallback? onError;
  final VoidCallback? onFlushPending;
  final GameStateCallback? onRematch;

  GameUpdateHandler({
    required this.net,
    required this.applyIncomingState,
    required this.isMounted,
    required this.getCurrentGame,
    this.onBackgroundMove,
    this.onGameOver,
    this.onError,
    this.onFlushPending,
    this.onRematch,
  });

  /// Compare deux GameState → même partie ?
  bool _sameGame(GameState a, GameState b) {
    final setA = {a.leftName, a.rightName};
    final setB = {b.leftName, b.rightName};
    return setA.length == 2 && setA.containsAll(setB);
  }

  void attach() {
    if (debug) {
      print('[GameUpdateHandler] attach (net=${net.hashCode})');
    }

    // ─────────────────────────────────────────────
    // GameState reçu
    // ─────────────────────────────────────────────
    net.onGameStateReceived = (incoming) async {
      final mounted = isMounted();
      final currentGame = getCurrentGame();
      final sameGame = _sameGame(incoming, currentGame);

      // 👉 Détection REVANCHE (sans isGameOver / isInitial)
      final bool isRematch =
          mounted &&
          !sameGame &&
          incoming.lettersPlacedThisTurn.isEmpty &&
          incoming.leftScore == 0 &&
          incoming.rightScore == 0;

      if (debug) {
        print(
          '[GameUpdateHandler] GameState reçu '
          '(sameGame=$sameGame, isRematch=$isRematch, mounted=$mounted)',
        );
      }

      // ✅ Même partie OU revanche → appliquer immédiatement
      // ✅ Même partie OU revanche → appliquer immédiatement
      if (mounted && (sameGame || isRematch)) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!isMounted()) return;

          await applyIncomingState(incoming, updateUI: true);
        });

        onFlushPending?.call();
        return;
      }

      // ❌ Autre partie → sauvegarde
      if (debug) {
        print('[GameUpdateHandler] Sauvegarde gameState (autre partie)');
      }
      await gameStorage.save(incoming);

      // 🔔 Notification passive (UI déléguée)
      onBackgroundMove?.call(incoming);

      // ▶️ Reprise polling
      net.startPolling(settings.localUserName);
    };

    // ─────────────────────────────────────────────
    // Game over
    // ─────────────────────────────────────────────
    net.onGameOverReceived = (finalState) async {
      if (!isMounted()) return;

      await gameStorage.delete(finalState.partnerFrom(settings.localUserName));

      onGameOver?.call(finalState);
    };

    // ─────────────────────────────────────────────
    // Erreur réseau
    // ─────────────────────────────────────────────
    net.onError = (message) {
      if (!isMounted()) return;
      onError?.call(message);
    };

    // ─────────────────────────────────────────────
    // Flush initial (sécurité)
    // ─────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) {
        onFlushPending?.call();
      }
    });
  }

  void detach() {
    if (debug) {
      print('[GameUpdateHandler] detach');
    }

    net.onGameStateReceived = null;
    net.onGameOverReceived = null;
    net.onError = null;
  }

  // ─────────────────────────────────────────────
  // Revanche (logique pure, UI déléguée)
  // ─────────────────────────────────────────────
  void handleRematch(GameState oldGameState) {
    final newGameState = GameInitializer.createGame(
      isLeft: oldGameState.isLeft,
      leftName: oldGameState.leftName,
      leftIP: oldGameState.leftIP,
      leftPort: oldGameState.leftPort,
      rightName: oldGameState.rightName,
      rightIP: oldGameState.rightIP,
      rightPort: oldGameState.rightPort,
    );

    net.resetGameOver();
    onRematch?.call(newGameState);
  }
}
