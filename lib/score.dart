import 'bonus.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/services/dictionary.dart';

String _normalize(String word) =>
    word.toUpperCase(); // ou removeAccents + upper

class InvalidWordException implements Exception {
  final String word;
  InvalidWordException(this.word);

  @override
  String toString() => 'Mot invalide: $word';
}

/* Fonctions utilitaires pour calcul score */
bool _isLikelyHorizontal(List<PlacedLetter> letters, List<List<String>> board) {
  if (letters.length == 1) {
    final l = letters.first;
    final hasLeft = l.col > 0 && board[l.row][l.col - 1].isNotEmpty;
    final hasRight = l.col < 14 && board[l.row][l.col + 1].isNotEmpty;
    return hasLeft || hasRight;
  } else {
    return letters.every((l) => l.row == letters.first.row);
  }
}

(bool, PlacedLetter?) _inPlaced(
  int row,
  int col,
  Map<(int, int), PlacedLetter> placedCoords,
) {
  final key = (row, col);
  if (placedCoords.containsKey(key)) {
    return (true, placedCoords[key]);
  }
  return (false, null);
}

(String word, int score) _extractWordWithScore(
  List<List<String>> board,
  List<List<BonusType>> bonusMap,
  int row,
  int col,
  int dRow,
  int dCol,
  Map<(int, int), PlacedLetter> placedCoords,
) {
  // Reculer jusqu’au début du mot
  while (_inBounds(row - dRow, col - dCol) &&
      board[row - dRow][col - dCol].isNotEmpty) {
    row -= dRow;
    col -= dCol;
  }

  final buffer = StringBuffer();
  int wordScore = 0;
  int wordMultiplier = 1;

  while (_inBounds(row, col) && board[row][col].isNotEmpty) {
    final letter = board[row][col];
    final placed = placedCoords[(row, col)];
    final isNewTile = placed != null;
    final isJoker = placed?.isJoker ?? false;
    final bonus = bonusMap[row][col];

    // ✅ JOKER = 0 POINT
    final baseScore = isJoker ? 0 : (letterPoints[letter.toUpperCase()] ?? 0);

    int letterScore = baseScore;

    // Bonus uniquement pour les lettres posées ce tour
    if (isNewTile) {
      switch (bonus) {
        case BonusType.doubleLetter:
          letterScore *= 2;
          break;
        case BonusType.tripleLetter:
          letterScore *= 3;
          break;
        case BonusType.doubleWord:
          wordMultiplier *= 2;
          break;
        case BonusType.tripleWord:
          wordMultiplier *= 3;
          break;
        case BonusType.none:
          break;
      }
    }

    wordScore += letterScore;
    buffer.write(letter);

    row += dRow;
    col += dCol;
  }

  final word = buffer.toString();
  return (word, wordScore * wordMultiplier);
}

bool _inBounds(int row, int col) {
  return row >= 0 && row < 15 && col >= 0 && col < 15;
}

/* Détection de tous les mots formés et calcul score total */
({List<String> words, int totalScore}) getWordsCreatedAndScore({
  required List<List<String>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required DictionaryService dictionary,
}) {
  if (lettersPlacedThisTurn.isEmpty) {
    return (words: [], totalScore: 0);
  }

  final words = <String>{};
  int totalScore = 0;

  // Pose temporaire des lettres
  for (final l in lettersPlacedThisTurn) {
    board[l.row][l.col] = l.letter;
  }

  final isHorizontal = _isLikelyHorizontal(lettersPlacedThisTurn, board);

  // 🔥 On garde l’info joker
  final placedCoords = {
    for (final l in lettersPlacedThisTurn) (l.row, l.col): l,
  };

  // --- Mot principal ---
  final start =
      isHorizontal
          ? lettersPlacedThisTurn.reduce((a, b) => a.col < b.col ? a : b)
          : lettersPlacedThisTurn.reduce((a, b) => a.row < b.row ? a : b);

  final (mainWord, mainScore) = _extractWordWithScore(
    board,
    bonusMap,
    start.row,
    start.col,
    isHorizontal ? 0 : 1,
    isHorizontal ? 1 : 0,
    placedCoords,
  );

  if (mainWord.length > 1) {
    final normalized = _normalize(mainWord);
    if (!dictionary.contains(normalized)) {
      throw InvalidWordException(normalized);
    }
    words.add(mainWord);
    totalScore += mainScore;
  }

  // --- Mots secondaires ---
  for (final l in lettersPlacedThisTurn) {
    final (perpWord, perpScore) = _extractWordWithScore(
      board,
      bonusMap,
      l.row,
      l.col,
      isHorizontal ? 1 : 0,
      isHorizontal ? 0 : 1,
      placedCoords,
    );

    if (perpWord.length > 1) {
      final normalized = _normalize(perpWord);
      if (!dictionary.contains(normalized)) {
        throw InvalidWordException(normalized);
      }
      words.add(perpWord);
      totalScore += perpScore;
    }
  }

  // 🎁 Bonus Scrabble
  if (lettersPlacedThisTurn.length == 7) {
    totalScore += 50;
  }

  return (words: words.toList(), totalScore: totalScore);
}
