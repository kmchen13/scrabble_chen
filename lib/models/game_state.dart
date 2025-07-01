import 'bag.dart';

class GameState {
  final List<List<String>> board;
  final List<String> playerLetters;
  final BagModel? bag;
  int hostScore;
  int clientScore;
  bool isClientTurn;

  GameState({
    required this.board,
    required this.playerLetters,
    required this.bag,
    this.hostScore = 0,
    this.clientScore = 0,
    this.isClientTurn = false,
  });

  static List<List<String>> createEmptyBoard(int size) {
    return List.generate(size, (_) => List.generate(size, (_) => ''));
  }

  factory GameState.initial(
    int boardSize,
    List<String> initialLetters,
    BagModel? bag,
  ) {
    return GameState(
      board: createEmptyBoard(boardSize),
      playerLetters: initialLetters,
      bag: bag,
    );
  }
}
