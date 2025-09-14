import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'utility.dart';
import 'game_end.dart';
import 'package:scrabble_P2P/models/game_state\.dart';
import '../constants.dart';

typedef ApplyIncomingState =
    void Function(GameState newState, {required bool updateUI});
typedef ShowEndGamePopup = void Function();

class GameUpdateHandler {
  final ScrabbleNet net;
  final BuildContext context;
  final ApplyIncomingState applyIncomingState;
  final ShowEndGamePopup showEndGamePopup;
  final bool mounted;

  GameUpdateHandler({
    required this.net,
    required this.context,
    required this.applyIncomingState,
    required this.showEndGamePopup,
    required this.mounted,
  });

  void attach() {
    // 🔥 Différer l’attachement du handler
    WidgetsBinding.instance.addPostFrameCallback((_) {
      net.onGameStateReceived = (newState) {
        print('${logHeader("GameUpdateHandler")} onGameStateReceived appelé');
        applyIncomingState(newState, updateUI: mounted);
      };
    });

    net.onGameOverReceived = (finalState) {
      if (debug) {
        print(
          '${logHeader("GameUpdateHandler")} onGameOverReceived (mounted=$mounted)',
        );
      }

      gameStorage.save(finalState);

      // Appliquer l’état final reçu
      applyIncomingState(finalState, updateUI: mounted);

      if (mounted) {
        GameEndService.showEndGamePopup(
          context: context,
          finalState: finalState,
          net: net,
          onRematchStarted: (newGameState) {
            // Utilise à nouveau applyIncomingState pour mettre à jour
            applyIncomingState(newGameState, updateUI: true);

            // Puis déclenche la popup de revanche
            showEndGamePopup();
          },
        );
      }
    };

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
  }
}
