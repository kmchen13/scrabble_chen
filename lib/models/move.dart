class GameMove {
  final String letter;
  final int row;
  final int col;

  GameMove({required this.letter, required this.row, required this.col});
}

typedef MovePlayedCallback = void Function(GameMove move);
