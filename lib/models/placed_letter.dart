class PlacedLetter {
  final int row;
  final int col;
  final String letter;
  final bool placedThisTurn;

  PlacedLetter({
    required this.row,
    required this.col,
    required this.letter,
    this.placedThisTurn = false,
  });

  PlacedLetter copyWith({bool? placedThisTurn}) {
    return PlacedLetter(
      row: row,
      col: col,
      letter: letter,
      placedThisTurn: placedThisTurn ?? this.placedThisTurn,
    );
  }
}
