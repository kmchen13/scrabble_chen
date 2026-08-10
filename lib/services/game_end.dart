import 'package:flutter/material.dart';
import 'package:scrabble_P2P/endgame_dialog.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/screens/home_screen.dart';

/// Service gérant la fin de partie et le lancement d’une revanche.
class GameEndService {
  static void showEndGamePopup({
    required BuildContext context,
    required GameState finalState,
    required ScrabbleNet net,
    required void Function(GameState newState) onRematchStarted,
  }) {
    final me = settings.localUser;
    final partner = finalState.partnerFrom(me);

    showEndGameDialog(
      context: context,
      gameState: finalState,

      /// 🔄 REVANCHE
      onRematch: () {
        final bool leftWon = finalState.leftScore > finalState.rightScore;

        final String newLeft =
            leftWon ? finalState.rightName : finalState.leftName;

        final String newRight =
            leftWon ? finalState.leftName : finalState.rightName;

        final bool iStart = settings.localUser == newLeft;

        if (!iStart) {
          // ✅ Je suis le nouveau joueur droit.
          // J'attends le 1er coup du joueur gauche.
          if (!iStart) {
            // ✅ Dialog informatif
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (context) => AlertDialog(
                    title: const Text("Revanche engagée"),
                    content: Text("À $newLeft de jouer."),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // ✅ Naviguer vers HomeScreen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HomeScreen(),
                            ),
                          );
                        },
                        child: const Text("Retour accueil"),
                      ),
                    ],
                  ),
            );

            return;
          }

          return;
        }

        // Je suis le nouveau joueur gauche :
        // je crée la nouvelle partie et je joue.

        final newGameState = GameInitializer.createGame(
          isLeft: true,
          leftName: newLeft,
          leftIP: '',
          leftPort: 0,
          rightName: newRight,
          rightIP: '',
          rightPort: 0,
        );

        onRematchStarted(newGameState);
      },

      /// 🏠 RETOUR À L’ACCUEIL
      onQuitToHome: () async {
        // ⭐️ notifier le partenaire
        await net.sendGameQuit(me, partner);

        // 🧹 nettoyage local
        await gameStorage.delete(partner);

        // 🏠 navigation
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      },
    );
  }
}
