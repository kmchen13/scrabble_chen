import 'placed_letter.dart';

class DraggedLetter {
  final String letter;
  final int fromIndex; // -1 si la lettre vient du board
  final int? row; // row si depuis board
  final int? col; // col si depuis board
  final bool fromBoard;
  final PlacedLetter? placedLetter; // ⚡ référence si déjà placé sur le board

  DraggedLetter({
    required this.letter,
    required this.fromIndex,
    this.row,
    this.col,
    this.placedLetter,
  }) : fromBoard = (fromIndex == -1);
}

const Map<String, int> letterPoints = {
  'A': 1, 'B': 3, 'C': 3, 'D': 2, 'E': 1, 'F': 4,
  'G': 2, 'H': 4, 'I': 1, 'J': 8, 'K': 10, 'L': 1,
  'M': 2, 'N': 1, 'O': 1, 'P': 3, 'Q': 8, 'R': 1,
  'S': 1, 'T': 1, 'U': 1, 'V': 4, 'W': 10, 'X': 10,
  'Y': 10, 'Z': 10, ' ': 0, // Joker
};
