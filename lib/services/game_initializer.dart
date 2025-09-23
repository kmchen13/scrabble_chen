import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/models/bag.dart';

class GameInitializer {
  static GameState createGame({
    required bool isLeft,
    required String leftName,
    required String leftIP,
    required int leftPort,
    required String rightName,
    required String rightIP,
    required int rightPort,
  }) {
    final BagModel bag = BagModel();
    final List<String> leftLetters = bag.drawLetters(7);
    final List<String> rightLetters = bag.drawLetters(7);

    final List<List<String>> board = List.generate(
      15,
      (_) => List.generate(15, (_) => ''),
    );

    return GameState(
      isLeft: isLeft, //Gauche joue le premier coup
      leftName: leftName,
      leftIP: leftIP,
      leftPort: leftPort,
      rightName: rightName,
      rightIP: rightIP,
      rightPort: rightPort,
      board: board,
      bag: bag,
      leftLetters: leftLetters,
      rightLetters: rightLetters,
      leftScore: 0,
      rightScore: 0,
      lettersPlacedThisTurn: [],
      gameId: '', // Initialisé plus tard
    );
  }
}
