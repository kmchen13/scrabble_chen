import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/utility.dart';
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

  final GameStateCallback? onBackgroundMove;
  final GameStateCallback? onGameOver;
  final GameStateCallback? onRematch;
  final StringCallback? onError;
  final VoidCallback? onFlushPending;

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

  bool _isRematch(GameState state) {
    return state.leftScore == 0 &&
        state.rightScore == 0 &&
        state.lettersPlacedThisTurn.isEmpty &&
        state.board.every((row) => row.every((c) => c.isEmpty));
  }

  void attach() {
    if (debug) {
      print('$logHeader(GameUpdateHandler) attach');
    }

    net.onGameStateReceived = (incoming) async {
      final mounted = isMounted();
      final currentGame = getCurrentGame();

      // 🔥 Comparaison par gameId (UNIQUE)
      final bool sameGame = currentGame.gameId == incoming.gameId;

      if (mounted && sameGame) {
        // Même partie → mise à jour
        await applyIncomingState(incoming, updateUI: true);
        return;
      }

      if (mounted && _isRematch(incoming)) {
        // C'est un rematch (nouvelle partie avec les mêmes joueurs)
        await applyIncomingState(incoming, updateUI: true);
        return;
      }

      // Autre partie → sauvegarde en arrière-plan
      onBackgroundMove?.call(incoming);
      net.startPolling(settings.localUserName);
    };

    /// GAMEOVER
    net.onGameOverReceived = (finalState) async {
      if (!isMounted()) return;

      // applique le dernier état reçu
      await applyIncomingState(finalState, updateUI: true);

      final me = settings.localUserName;

      final iAmLeft = me == finalState.leftName;
      final iAmRight = me == finalState.rightName;

      if (iAmLeft) {
        // Je suis G, je reçois le GAMEOVER de D la partie e
        if (debug)
          print(
            "$logHeader( GameUpdateHandler) Je suis G, je reçois le GAMEOVER de D, partie terminée affichage du popup si $onGameOver != null",
          );
        await gameStorage.delete(finalState.partnerFrom(me));
        if (onGameOver != null) {
          onGameOver!.call(finalState);
        } else {
          print("⚠️ onGameOver est NULL !");
        }
        return;
      }

      if (iAmRight) {
        // Je suis D, je reçois le GAMEOVER de G je joue le dernier coup. handleSubmit détectera que G est vide donc la partie est finie. popup
        return;
      }
    };

    /// Error
    net.onError = (message) {
      if (!isMounted()) return;

      onError?.call(message);
    };

    /// flush initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) {
        onFlushPending?.call();
      }
    });
  }

  void detach() {
    net.onGameStateReceived = null;
    net.onGameOverReceived = null;
    net.onError = null;
  }

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
