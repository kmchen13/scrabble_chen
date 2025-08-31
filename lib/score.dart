import 'bonus.dart';
import 'models/dragged_letter.dart';
import 'models/placed_letter.dart';

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

(bool, String) _inPlaced(
  int row,
  int col,
  Map<(int, int), String> placedCoords,
) {
  final key = (row, col);
  if (placedCoords.containsKey(key)) {
    return (true, placedCoords[key]!);
  }
  return (false, '');
}

(String word, int score) _extractWordWithScore(
  List<List<String>> board,
  List<List<BonusType>> bonusMap,
  int row,
  int col,
  int dRow,
  int dCol,
  Map<(int, int), String> placedCoords,
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
    final isNewTile = placedCoords.containsKey((row, col));
    final bonus = bonusMap[row][col];

    final baseScore = letterPoints[letter.toUpperCase()] ?? 0;
    int letterScore = baseScore;

    // Appliquer bonus uniquement si la lettre vient d'être posée
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
  final totalScore = wordScore * wordMultiplier;

  return (word, totalScore);
}

bool _inBounds(int row, int col) {
  return row >= 0 && row < 15 && col >= 0 && col < 15;
}

/* Détection de tous les mots formés et calcul score total */
({List<String> words, int totalScore}) getWordsCreatedAndScore({
  required List<List<String>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
}) {
  if (lettersPlacedThisTurn.isEmpty) {
    return (words: [], totalScore: 0);
  }

  final words = <String>{};
  int totalScore = 0;

  // Temporairement poser les lettres sur le plateau
  for (final l in lettersPlacedThisTurn) {
    board[l.row][l.col] = l.letter;
  }

  bool isHorizontal = _isLikelyHorizontal(lettersPlacedThisTurn, board);

  final placedCoords = {
    for (final l in lettersPlacedThisTurn) (l.row, l.col): l.letter,
  };

  if (isHorizontal) {
    // Lettre placée avec la plus petite colonne
    final start = lettersPlacedThisTurn.reduce((a, b) => a.col < b.col ? a : b);
    final (mainWord, mainScore) = _extractWordWithScore(
      board,
      bonusMap,
      start.row,
      start.col,
      0,
      1,
      placedCoords,
    );
    if (mainWord.length > 1) {
      words.add(mainWord);
      totalScore += mainScore;
    }
  } else {
    // Lettre placée avec la plus petite ligne
    final start = lettersPlacedThisTurn.reduce((a, b) => a.row < b.row ? a : b);
    final (mainWord, mainScore) = _extractWordWithScore(
      board,
      bonusMap,
      start.row,
      start.col,
      1,
      0,
      placedCoords,
    );
    if (mainWord.length > 1) {
      words.add(mainWord);
      totalScore += mainScore;
    }
  }

  // Mots secondaires perpendiculaires
  for (final l in lettersPlacedThisTurn) {
    final (perpWord, perpScore) =
        isHorizontal
            ? _extractWordWithScore(
              board,
              bonusMap,
              l.row,
              l.col,
              1,
              0,
              placedCoords,
            )
            : _extractWordWithScore(
              board,
              bonusMap,
              l.row,
              l.col,
              0,
              1,
              placedCoords,
            );

    if (perpWord.length > 1) {
      words.add(perpWord);
      totalScore += perpScore;
    }
  }
  // Bonus Scrabble : 7 lettres jouées
  if (lettersPlacedThisTurn.length == 7) totalScore += 50;

  return (words: words.toList(), totalScore: totalScore);
}
