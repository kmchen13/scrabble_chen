import 'package:flutter/material.dart';
import 'dragged_letter.dart';

const int boardSize = 15;

Widget buildScrabbleBoard({
  required List<List<String>> board,
  required List<String> playerLetters,
  required List<({int row, int col, String letter})> lettersPlacedThisTurn,
  required void Function(String letter, int row, int col) onLetterPlaced,
  required void Function(String letter) onLetterReturned,
}) {
  return GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: boardSize,
    ),
    itemCount: boardSize * boardSize,
    itemBuilder: (context, index) {
      final row = index ~/ boardSize;
      final col = index % boardSize;
      final bonus = bonusMap[row][col];
      final bgColor = getColorForBonus(bonus);
      final cellLetter = board[row][col];

      // ✅ Vérifie si cette case fait partie des lettres du tour
      final isPlacedThisTurn = lettersPlacedThisTurn.any(
        (pos) => pos.row == row && pos.col == col,
      );

      return DragTarget<DraggedLetter>(
        onWillAccept: (data) {
          // Accepte si la case est vide
          return board[row][col].isEmpty;
        },
        onAcceptWithDetails: (details) {
          final letter = details.data.letter;
          if (board[row][col].isEmpty) {
            onLetterPlaced(letter, row, col);
          }
        },
        builder: (context, candidateData, rejectedData) {
          final cellLetter = board[row][col];
          final isPlacedThisTurn = lettersPlacedThisTurn.any(
            (pos) => pos.row == row && pos.col == col,
          );

          return GestureDetector(
            onTap: () {
              if (isPlacedThisTurn && cellLetter.isNotEmpty) {
                onLetterReturned(cellLetter); // ✅ Retourne dans le rack
              }
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: cellLetter.isNotEmpty ? Colors.amber : Colors.grey,
                ),
                color:
                    cellLetter.isNotEmpty
                        ? Colors.amber[200]
                        : getColorForBonus(bonusMap[row][col]),
              ),
              child: Center(
                child: Text(
                  cellLetter.isNotEmpty
                      ? cellLetter
                      : bonusLabel(bonusMap[row][col]),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

enum BonusType { none, doubleLetter, tripleLetter, doubleWord, tripleWord }

const List<List<BonusType>> bonusMap = [
  [
    BonusType.tripleWord,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.tripleWord,
  ],
  [
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.tripleWord,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.tripleWord,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
  ],
  [
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
  ],
  [
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleWord,
    BonusType.none,
  ],
  [
    BonusType.tripleWord,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.tripleWord,
    BonusType.none,
    BonusType.none,
    BonusType.none,
    BonusType.doubleLetter,
    BonusType.none,
    BonusType.none,
    BonusType.tripleWord,
  ],
];

Color getColorForBonus(BonusType bonus) {
  switch (bonus) {
    case BonusType.doubleLetter:
      return const Color(0xFF76B8CC);
    case BonusType.tripleLetter:
      return const Color(0xFF0F427D);
    case BonusType.doubleWord:
      return const Color(0xFFE3A798);
    case BonusType.tripleWord:
      return const Color(0xFFAB0401);
    case BonusType.none:
      return const Color(0xFFCAC5AD);
  }
}

String bonusLabel(BonusType bonus) {
  switch (bonus) {
    case BonusType.doubleLetter:
      return "LD";
    case BonusType.tripleLetter:
      return "LT";
    case BonusType.doubleWord:
      return "MD";
    case BonusType.tripleWord:
      return "MT";
    default:
      return "";
  }
}
