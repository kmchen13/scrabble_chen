import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'utility.dart';
import 'game_end.dart';
import 'package:scrabble_P2P/models/game_state.dart';
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
    // 🔥 Différer l’attachement du handler à quand le screen est affiché
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (debug) {
        print(
          '${logHeader("GameUpdateHandler")} net hashCode = ${net.hashCode} mounted=$mounted',
        );
      }

      // Handler des GameState entrants
      net.onGameStateReceived = (newState) {
        applyIncomingState(newState, updateUI: mounted);
      };

      // Handler de fin de partie
      net.onGameOverReceived = (finalState) {
        // Supprime la sauvegarde de la partie
        gameStorage.delete(finalState.partnerFrom(settings.localUserName));

        if (!mounted) {
          print('[GameUpdateHandler] Fin de partie ignorée (non monté)');
          return;
        }

        // Affiche la popup pour tous
        GameEndService.showEndGamePopup(
          context: context,
          finalState: finalState,
          net: net,
          onRematchStarted: (newGameState) {
            // ⚡ Callback quand le premier coup est joué
            applyIncomingState(newGameState, updateUI: true);
            net.startPolling(newGameState.rightName);
            net.resetGameOver();
          },
        );
      };

      // Flush messages en attente
      if (mounted) {
        Future.microtask(() => net.flushPending());
      }

      net.onError = (message) {
        if (mounted) {
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
      };

      net.onConnectionClosed = () {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Votre partenaire s'est déconnecté")),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        }
      };
    });
  }

  void detach() {
    net.onGameStateReceived = null;
    net.onGameOverReceived = null;
    net.onError = null;
    net.onConnectionClosed = null;
  }
}
