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
  final bool mounted;

  GameUpdateHandler({
    required this.net,
    required this.context,
    required this.applyIncomingState,
    required this.mounted,
  });

  void attach() {
    if (debug) {
      print(
        '${logHeader("GameUpdateHandler")} Installing callbacks immediately; net hashCode = ${net.hashCode}, mounted=$mounted',
      );
    }

    // 🔁 Callback GameState normal
    net.onGameStateReceived = (newState) {
      applyIncomingState(newState, updateUI: mounted);
    };

    // 📌 Fonction interne pour gérer la revanche
    void handleRematch(GameState oldGameState) {
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

      // 🔑 Réinstaller callbacks AVANT navigation
      net.onGameStateReceived = (gs) {
        applyIncomingState(gs, updateUI: true);
      };
      net.onGameOverReceived = (finalState) {
        GameEndService.showEndGamePopup(
          context: context,
          finalState: finalState,
          net: net,
          onRematchStarted: handleRematch,
        );
      };

      // 🔄 Flush immédiat des GameState bufferisés
      net.flushPending();

      // Joueur de gauche commence
      if (localName == newGameState.leftName) {
        applyIncomingState(newGameState, updateUI: true);
      }

      // Naviguer vers le nouveau GameScreen
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

      net.resetGameOver();

      // Joueur de droite attend → start polling
      if (localName != newGameState.leftName) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text("Au partenaire de jouer"),
            action: SnackBarAction(
              label: 'Fermer',
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
            duration: const Duration(minutes: 1),
          ),
        );
        net.startPolling(newGameState.rightName);
      }
    }

    // 🔥 Callback de fin de partie
    net.onGameOverReceived = (finalState) {
      gameStorage.delete(finalState.partnerFrom(settings.localUserName));

      if (!mounted) {
        print('[GameUpdateHandler] Fin de partie ignorée (non monté)');
        return;
      }

      GameEndService.showEndGamePopup(
        context: context,
        finalState: finalState,
        net: net,
        onRematchStarted: handleRematch,
      );
    };

    // ⏳ Flush messages en attente après le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (debug) {
          print(
            '${logHeader("GameUpdateHandler")} 🔄 Flushing pending messages...',
          );
        }
        net.flushPending();
      }
    });

    // 🔥 Callback erreur
    net.onError = (message) {
      if (!mounted) return;
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

    // 🔥 Callback déconnexion partenaire
    net.onConnectionClosed = () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Votre partenaire s'est déconnecté")),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    };
  }

  void detach() {
    net.onError = null;
    net.onConnectionClosed = null;
  }
}
