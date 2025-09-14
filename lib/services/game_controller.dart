import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'game_storage.dart';
import '../score.dart';
import 'package:scrabble_P2P/screens/show_bag.dart';

class GameController {
  final ScrabbleNet net;
  final VoidCallback onStateChanged;
  final void Function(GameState) onGameOver;

  GameController({
    required this.net,
    required this.onStateChanged,
    required this.onGameOver,
  });

  /// Valide le coup courant
  void handleSubmit({
    required GameState state,
    required List<PlacedLetter> lettersThisTurn,
    required List<String> playerRack,
  }) {
    if (lettersThisTurn.isEmpty) return;

    // Met à jour le plateau et calcule le score
    final result = getWordsCreatedAndScore(
      board: state.board,
      lettersPlacedThisTurn: lettersThisTurn,
    );
    final totalScore = result.totalScore;

    if (state.isLeft) {
      state.leftScore += totalScore;
    } else {
      state.rightScore += totalScore;
    }

    // Supprime les lettres du sac
    for (final placed in lettersThisTurn) {
      state.board[placed.row][placed.col] = placed.letter;
      state.bag.removeLetter(placed.letter);
    }

    // Met à jour le GameState
    state.lettersPlacedThisTurn = List.from(lettersThisTurn);
    refillRack(playerRack, 7, state);
    state.isLeft = !state.isLeft;

    // Envoie le GameState
    net.sendGameState(state);

    // Sauvegarde dans Hive
    gameStorage.save(state);

    // Notification UI
    onStateChanged();

    // Fin de partie ?
    if (playerRack.isEmpty) {
      onGameOver(state);
      net.sendGameOver(state);
    }

    lettersThisTurn.clear();
  }

  /// Annule le coup courant
  void handleUndo({
    required GameState state,
    required List<PlacedLetter> lettersThisTurn,
    required List<String> playerRack,
  }) {
    for (final placed in lettersThisTurn) {
      playerRack.add(placed.letter);
      state.board[placed.row][placed.col] = '';
    }
    lettersThisTurn.clear();

    // Notification UI
    onStateChanged();
  }

  /// Affiche le sac
  void handleShowBag(BuildContext context, GameState state) {
    state.bag.showContents(context);
  }
}

void refillRack(List<String> rack, int maxLetters, dynamic gameState) {
  int missing = maxLetters - rack.length;
  if (missing > 0) {
    final drawn = gameState.bag.drawLetters(missing);
    rack.addAll(drawn);

    // ✅ MISE À JOUR du GameState avec les nouvelles lettres
    if (gameState.isLeft) {
      gameState.leftLetters = List.from(rack);
    } else {
      gameState.rightLetters = List.from(rack);
    }
  }
}
