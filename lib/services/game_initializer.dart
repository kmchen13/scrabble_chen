import '../models/bag.dart';
import '../models/game_state.dart';

class GameInitializer {
  static GameCreationResult createGame({int boardSize = 15}) {
    final bag = BagModel();
    final hostLetters = bag.drawLetters(7);
    final clientLetters = bag.drawLetters(7);

    final hostGameState = GameState(
      board: GameState.createEmptyBoard(boardSize),
      playerLetters: hostLetters,
      bag: bag,
    );

    final clientGameState = GameState(
      board: GameState.createEmptyBoard(boardSize),
      playerLetters: clientLetters,
      bag: bag,
      isClientTurn: true, // Client commence
    );

    return GameCreationResult(
      hostGameState: hostGameState,
      clientGameState: clientGameState,
    );
  }
}

class GameCreationResult {
  final GameState hostGameState;
  final GameState clientGameState;

  GameCreationResult({
    required this.hostGameState,
    required this.clientGameState,
  });
}
