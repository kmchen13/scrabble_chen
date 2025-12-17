import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'utility.dart';
import 'game_end.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import '../constants.dart';

typedef ApplyIncomingState =
    void Function(GameState newState, {required bool updateUI});

class GameUpdateHandler {
  final ScrabbleNet net;
  final BuildContext context;
  final ApplyIncomingState applyIncomingState;
  final bool Function() isMounted;
  final GameState Function() getCurrentGame;

  GameUpdateHandler({
    required this.net,
    required this.context,
    required this.applyIncomingState,
    required this.isMounted,
    required this.getCurrentGame,
  });

  /// Compare deux GameState → même partie ?
  bool _sameGame(GameState a, GameState b) {
    final setA = {a.leftName, a.rightName};
    final setB = {b.leftName, b.rightName};
    return setA.length == 2 && setA.containsAll(setB);
  }

  /// Écran courant visible ?
  bool _isCurrentScreenActive() {
    final route = ModalRoute.of(context);
    return route?.isCurrent == true;
  }

  void attach(GameState currentGame) {
    if (debug) {
      print('[GameUpdateHandler] attach (net=${net.hashCode})');
    }

    net.onGameStateReceived = (incoming) async {
      final mounted = isMounted();
      final currentGame = getCurrentGame();
      final sameGame = _sameGame(incoming, currentGame);
      final screenActive = mounted && _isCurrentScreenActive();

      if (debug) {
        print(
          '[GameUpdateHandler] GameState reçu '
          '(sameGame=$sameGame, active=$screenActive)',
        );
      }

      // 1️⃣ Même partie + écran actif → appliquer immédiatement
      if (sameGame && screenActive) {
        applyIncomingState(incoming, updateUI: true);
        return;
      }

      // 3️⃣ Autre cas → sauvegarde
      await gameStorage.save(incoming);

      if (mounted && sameGame) {
        final partner = incoming.partnerFrom(settings.localUserName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$partner a joué un coup"),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // 4️⃣ Relance polling
      net.startPolling(settings.localUserName);

      if (debug) {
        print(
          '[GameUpdateHandler] GameState sauvegardé '
          '(game_${incoming.partnerFrom(settings.localUserName)})',
        );
      }
    };

    net.onGameOverReceived = (finalState) {
      if (!isMounted()) return;

      gameStorage.delete(finalState.partnerFrom(settings.localUserName));

      GameEndService.showEndGamePopup(
        context: context,
        finalState: finalState,
        net: net,
        onRematchStarted: (oldState) {
          _handleRematch(oldState);
        },
      );
    };

    net.onError = (message) {
      if (!isMounted()) return;

      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Erreur réseau'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ],
            ),
      );
    };

    net.onConnectionClosed = () {
      if (!isMounted()) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Votre partenaire s'est déconnecté")),
      );

      Navigator.of(context).popUntil((r) => r.isFirst);
    };

    // Flush après build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMounted()) {
        net.flushPending();
      }
    });
  }

  void _handleRematch(GameState oldGameState) {
    final localName = settings.localUserName;

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

    if (localName == newGameState.leftName) {
      applyIncomingState(newGameState, updateUI: true);
    } else {
      net.startPolling(newGameState.rightName);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              gameState: newGameState,
              net: net,
              onGameStateUpdated: (gs) => net.sendGameState(gs),
            ),
      ),
    );
  }
}
