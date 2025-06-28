import 'bag.dart';

class GameState {
  final List<List<String>> board;
  final List<String> playerLetters;
  final BagModel? bag; // ✅ nullable

  GameState({
    required this.board,
    required this.playerLetters,
    this.bag, // ✅ optionnel
  });

  static List<List<String>> createEmptyBoard(int size) {
    return List.generate(size, (_) => List.generate(size, (_) => ''));
  }
}
