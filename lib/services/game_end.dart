import 'package:flutter/material.dart';

import 'package:scrabble_P2P/endgame_dialog.dart';
import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';

/// Service gérant la fin de partie et le lancement d’une revanche.
class GameEndService {
  /// Affiche la popup de fin de partie et lance une revanche si demandé.
  static void showEndGamePopup({
    required BuildContext context,
    required GameState finalState,
    required ScrabbleNet net,
    required void Function(GameState newState) onRematchStarted,
  }) {
    showEndGameDialog(context, finalState, () {
      // 🔄 Préparer une revanche
      final bool leftWon = finalState.leftScore > finalState.rightScore;

      // On inverse les joueurs pour que celui qui a perdu commence à gauche
      final String newLeft =
          leftWon ? finalState.rightName : finalState.leftName;
      final String newRight =
          leftWon ? finalState.leftName : finalState.rightName;

      final newGameState = GameInitializer.createGame(
        isLeft: true, // ← côté local reste à gauche
        leftName: newLeft,
        leftIP: '',
        leftPort: 0,
        rightName: newRight,
        rightIP: '',
        rightPort: 0,
      );

      // ✅ Callback vers GameScreen pour appliquer le nouvel état localement
      onRematchStarted(newGameState);

      // 📤 Envoi au partenaire
      net.sendGameState(newGameState);
    });
  }
}
