class DraggedLetter {
  final String letter;
  final int fromIndex; // -1 si la lettre vient du board
  final int? row; // row si depuis board
  final int? col; // col si depuis board
  final bool fromBoard;

  DraggedLetter({
    required this.letter,
    required this.fromIndex,
    this.row,
    this.col,
  }) : fromBoard = (fromIndex == -1);
}
