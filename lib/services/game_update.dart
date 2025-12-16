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

  GameUpdateHandler({
    required this.net,
    required this.context,
    required this.applyIncomingState,
    required this.isMounted,
  });

  void attach() {
    if (debug) {
      print('${logHeader("GameUpdateHandler")} attach (net=${net.hashCode})');
    }

    // 🎮 GameState reçu
    net.onGameStateReceived = _onGameStateReceived;

    // 🏁 Fin de partie
    net.onGameOverReceived = _onGameOverReceived;

    // ❌ Erreur réseau
    net.onError = _onError;

    // 🔌 Déconnexion partenaire
    net.onConnectionClosed = _onConnectionClosed;
  }

  // =========================================================
  // Callbacks
  // =========================================================

  void _onGameStateReceived(GameState state) {
    if (!isMounted()) return;
    applyIncomingState(state, updateUI: true);
  }

  void _onGameOverReceived(GameState finalState) {
    gameStorage.delete(finalState.partnerFrom(settings.localUserName));

    if (!isMounted()) return;

    GameEndService.showEndGamePopup(
      context: context,
      finalState: finalState,
      net: net,
      onRematchStarted: _handleRematch,
    );
  }

  void _onError(String message) {
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
  }

  void _onConnectionClosed() {
    if (!isMounted()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Votre partenaire s'est déconnecté")),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // =========================================================
  // Revanche
  // =========================================================

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

    // Joueur de gauche commence
    if (localName == newGameState.leftName) {
      applyIncomingState(newGameState, updateUI: true);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              gameState: newGameState,
              net: net,
              onGameStateUpdated: net.sendGameState,
            ),
      ),
    );

    net.resetGameOver();

    // Joueur de droite attend
    if (localName != newGameState.leftName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Au perdant de jouer"),
          duration: Duration(minutes: 1),
        ),
      );
      net.startPolling(newGameState.rightName);
    }
  }

  // =========================================================

  void detach() {
    net.onGameStateReceived = null;
    net.onGameOverReceived = null;
    net.onError = null;
    net.onConnectionClosed = null;
  }
}
