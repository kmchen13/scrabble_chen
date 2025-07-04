import '../models/game_state.dart';
import '../models/bag.dart';
import 'settings_service.dart';

class GameInitializer {
  static ({GameState gameState}) createGame() {
    final bag = BagModel();
    final hostLetters = bag.drawLetters(7);
    final clientLetters = bag.drawLetters(7);

    final gameState = GameState(
      board: GameState.createEmptyBoard(15),
      bag: bag,
      hostLetters: hostLetters,
      clientLetters: clientLetters,
      hostUserName: settings.localUserName, // Celui qui initialise
      clientUserName: '', // sera rempli côté client après réception
      isClientTurn: true, // le client commence
      hostScore: 0,
      clientScore: 0,
    );

    return (gameState: gameState);
  }
}
