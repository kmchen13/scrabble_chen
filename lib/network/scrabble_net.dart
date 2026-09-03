import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/models/game_state\.dart';
import 'local_net.dart';
import 'relay_net.dart';

// Dans relay_net.dart (ou un fichier séparé)
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

abstract class ScrabbleNet {
  factory ScrabbleNet() {
    if (settings.communicationMode == 'web') {
      return RelayNet(); // Assure-toi que cette classe existe
    } else {
      return LocalNet();
    }
  }
  // Connexion des joueurs
  // Tous les joueurs font une demande de partenaire avec leur nom et le nom éventuel souhaité d'un partenaire
  // Si deux joueurs "matchent" on execute un callback définit dans la couche métier (start_screen)
  Future<void> connect({
    required String localName,
    required String expectedName,
    required int startTime,
  });

  /// Callback appelé quand deux joueurs matchent
  void Function({
    required String leftName,
    required String leftIP,
    required int leftPort,
    required int leftStartTime,
    required String rightName,
    required String rightIP,
    required int rightPort,
    required int rightStartTime,
  })?
  onMatched;

  // Deux joueurs matchent si leur local et expected names correspondent ou si leurs expected sont vides
  // Si plus de 2 joueurs n'ont pas défini expected les 2 premiers trouvés sont connectés
  static bool match(
    String localUser,
    String expectedUser,
    String remoteUser,
    String remoteExpected,
  ) {
    return (localUser == remoteExpected && expectedUser == remoteUser) ||
        (remoteExpected == '' && expectedUser == '');
  }

  Future<List<Map<String, dynamic>>> getFreePlayers();

  // Envoi d'un GameState au partenaire
  void sendGameState(GameState state);

  // Réception d'un GameState
  void Function(GameState)? onGameStateReceived;

  // Envoi d'un GameOver au partenaire
  void sendGameOver(GameState state);

  // Réception d'un GameOver
  void Function(GameState)? onGameOverReceived;

  /// Quitte la partie en cours
  Future<void> sendGameQuit(user, partner);

  /// Callback appelé quand un joueur quitte la partie
  void Function(String partner)? onGameQuitReceived;

  // Spécifique au mode web (RelayNet)
  // @todo ne devrait pas être ici.
  void startPolling(String localName) {}
  void stopPolling() {}

  void Function(String message)? onStatusUpdate;

  /// En mode local déconnecte TDP ert UDP. En mode WEB rien à faire
  Future<void> disconnect();

  /// La connexion est fermée (par quit ou déconnexion)
  void setOnConnectionClosed(
    void Function(String partner, String reason)? callback,
  );

  /// Réinitialise l'état de fin de partie pour permettre d'envoyer des GameState à nouveau
  void resetGameOver();

  void Function(String message)? onError;
}
