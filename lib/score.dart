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

bool _inBounds(int row, int col) {
  return row >= 0 && row < 15 && col >= 0 && col < 15;
}

(String word, int score) _extractWordWithScore(
  List<List<String>> board,
  List<List<BonusType>> bonusMap,
  int row,
  int col,
  int dRow,
  int dCol,
  Map<(int, int), PlacedLetter> placedCoords,
  List<List<Map<String, dynamic>?>> boardJokerInfo, // NOUVEAU paramètre
) {
  // Reculer jusqu'au début du mot
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

    // ✅ Vérifier si c'est un joker (d'abord dans placed, sinon dans boardJokerInfo)
    final isJoker =
        placed?.isJoker ??
        (boardJokerInfo[row][col]?['isJoker'] as bool? ?? false);

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

// Mettre à jour getWordsCreatedAndScore
({List<String> words, int totalScore}) getWordsCreatedAndScore({
  required List<List<String>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required DictionaryService dictionary,
  required List<List<Map<String, dynamic>?>>
  boardJokerInfo, // NOUVEAU paramètre
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
    boardJokerInfo, // ✅ PASSER boardJokerInfo
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
      boardJokerInfo, // ✅ PASSER boardJokerInfo
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

// Mettre à jour getWordAtPosition
String? getWordAtPosition({
  required List<List<String>> board,
  required int row,
  required int col,
  List<List<Map<String, dynamic>?>>?
  boardJokerInfo, // NOUVEAU paramètre optionnel
}) {
  if (board[row][col].isEmpty) return null;

  final placedCoords = <(int, int), PlacedLetter>{};
  final jokerInfo =
      boardJokerInfo ??
      List.generate(15, (_) => List<Map<String, dynamic>?>.filled(15, null));

  final (horizontalWord, _) = _extractWordWithScore(
    board,
    bonusMap,
    row,
    col,
    0,
    1,
    placedCoords,
    jokerInfo,
  );

  final (verticalWord, _) = _extractWordWithScore(
    board,
    bonusMap,
    row,
    col,
    1,
    0,
    placedCoords,
    jokerInfo,
  );

  if (horizontalWord.length >= verticalWord.length &&
      horizontalWord.length > 1) {
    return horizontalWord;
  }

  if (verticalWord.length > 1) {
    return verticalWord;
  }

  return null;
}
