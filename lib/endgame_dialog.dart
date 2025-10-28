import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/verification.dart';
import 'screens/home_screen.dart';

Future<void> showEndGameDialog(
  BuildContext context,
  GameState gameState,
  VoidCallback onRematch,
) async {
  verification(gameState, context);

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
            "Le gagnant est : $winner\n\nScore final :\n"
            "${gameState.leftName}: ${gameState.leftScore}\n"
            "${gameState.rightName}: ${gameState.rightScore}",
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
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text("Retour à l'accueil"),
            ),
          ],
        ),
  );
}
