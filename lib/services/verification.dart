import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state.dart';

void verification(gameState, context) {
  // 🧮 Vérification cohérence du nombre de jetons
  int lettersOnBoard = 0;
  for (int row = 0; row < gameState.board.length; row++) {
    for (int col = 0; col < gameState.board[row].length; col++) {
      if (gameState.board[row][col].isNotEmpty) {
        lettersOnBoard++;
      }
    }
  }

  int lettersInRacks =
      gameState.leftLetters.length + gameState.rightLetters.length;
  int lettersInBag = gameState.bag.remainingCount;
  int totalLetters = lettersOnBoard + lettersInBag + lettersInRacks;
  int expectedTotal = gameState.bag.totalTiles;
  int difference = (totalLetters - expectedTotal).abs();

  if (totalLetters != expectedTotal) {
    // ⚠️ Alerte si incohérence détectée
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⚠️ Erreur de cohérence : jetons en début de partie = $expectedTotal, en fin = $totalLetters \n\n Qui a piqué $difference jetons ?!",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
        duration: const Duration(
          days: 1,
        ), // rendu persistant tant que non fermé
      ),
    );
  }
}
