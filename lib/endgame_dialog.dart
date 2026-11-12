import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/utility.dart';

Future<void> showEndGameDialog({
  required BuildContext context,
  required GameState gameState,
  required VoidCallback onRematch,
  required Future<void> Function() onQuitToHome,
}) async {
  //supprimer l'ancienne partie
  final me = settings.localUserName;
  final partner = gameState.partnerFrom(me);
  gameStorage.delete(partner);

  String winner =
      gameState.leftScore == gameState.rightScore
          ? "Égalité !"
          : (gameState.leftScore > gameState.rightScore
              ? gameState.leftName
              : gameState.rightName);

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => AlertDialog(
          title: const Text("Fin de la partie"),
          content: Text(
            "Le gagnant est : ${displayName(winner)}\n\n"
            "Score final :\n"
            "${displayName(gameState.leftName)}: ${gameState.leftScore}\n"
            "${displayName(gameState.rightName)}: ${gameState.rightScore}",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRematch();
              },
              child: const Text("Revanche"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await onQuitToHome();
              },
              child: const Text("Retour à l'accueil"),
            ),
          ],
        ),
  );
}
