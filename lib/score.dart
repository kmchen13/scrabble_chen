import 'bonus.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/services/dictionary.dart';

String _normalize(String word) => word.toUpperCase();

class InvalidWordException implements Exception {
  final String word;
  InvalidWordException(this.word);

  @override
  String toString() => 'Mot invalide: $word';
}

// ==============================
// 🔍 ORIENTATION
// ==============================
bool _isLikelyHorizontal(
  List<PlacedLetter> letters,
  List<List<PlacedLetter?>> board,
) {
  if (letters.length == 1) {
    final l = letters.first;

    final hasLeft =
        l.col > 0 && (board[l.row][l.col - 1]?.displayLetter ?? '').isNotEmpty;

    final hasRight =
        l.col < 14 && (board[l.row][l.col + 1]?.displayLetter ?? '').isNotEmpty;

    return hasLeft || hasRight;
  } else {
    return letters.every((l) => l.row == letters.first.row);
  }
}

// ==============================
// 🔧 UTILS
// ==============================
bool _inBounds(int row, int col) {
  return row >= 0 && row < 15 && col >= 0 && col < 15;
}

// ==============================
// 🔠 EXTRACTION MOT + SCORE
// ==============================
(String word, int score) _extractWordWithScore(
  List<List<PlacedLetter?>> board,
  List<List<BonusType>> bonusMap,
  int row,
  int col,
  int dRow,
  int dCol,
  Map<(int, int), PlacedLetter> placedCoords,
) {
  // 🔙 reculer au début du mot
  while (_inBounds(row - dRow, col - dCol) &&
      (board[row - dRow][col - dCol]?.displayLetter ?? '').isNotEmpty) {
    row -= dRow;
    col -= dCol;
  }

  final buffer = StringBuffer();
  int wordScore = 0;
  int wordMultiplier = 1;

  while (_inBounds(row, col) &&
      (board[row][col]?.displayLetter ?? '').isNotEmpty) {
    final placed = placedCoords[(row, col)];
    final boardLetter = board[row][col];

    final letter = placed?.displayLetter ?? boardLetter?.displayLetter ?? '';
    final isJoker = placed?.isJoker ?? boardLetter?.isJoker ?? false;

    final bonus = bonusMap[row][col];
    final isNewTile = placed != null;

    // ✅ Joker = 0 point
    final baseScore = isJoker ? 0 : (letterPoints[letter.toUpperCase()] ?? 0);

    int letterScore = baseScore;

    // bonus seulement pour lettres posées ce tour
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

// ==============================
// 🧠 CALCUL GLOBAL
// ==============================
({List<String> words, int totalScore}) getWordsCreatedAndScore({
  required List<List<PlacedLetter?>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required DictionaryService dictionary,
}) {
  if (lettersPlacedThisTurn.isEmpty) {
    return (words: [], totalScore: 0);
  }

  final words = <String>{};
  int totalScore = 0;

  // 🔥 map rapide des lettres posées
  final placedCoords = {
    for (final l in lettersPlacedThisTurn) (l.row, l.col): l,
  };

  final isHorizontal = _isLikelyHorizontal(lettersPlacedThisTurn, board);

  // =============================
  // 🟥 MOT PRINCIPAL
  // =============================
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

  // =============================
  // 🟦 MOTS SECONDAIRES
  // =============================
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

  // 🎁 bonus Scrabble
  if (lettersPlacedThisTurn.length == 7) {
    totalScore += 50;
  }

  return (words: words.toList(), totalScore: totalScore);
}

// ==============================
// 🔎 MOT À UNE POSITION
// ==============================
String? getWordAtPosition({
  required List<List<PlacedLetter?>> board,
  required int row,
  required int col,
}) {
  final cell = board[row][col];
  if (cell == null) return null;

  final placedCoords = <(int, int), PlacedLetter>{};

  final (horizontalWord, _) = _extractWordWithScore(
    board,
    bonusMap,
    row,
    col,
    0,
    1,
    placedCoords,
  );

  final (verticalWord, _) = _extractWordWithScore(
    board,
    bonusMap,
    row,
    col,
    1,
    0,
    placedCoords,
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
