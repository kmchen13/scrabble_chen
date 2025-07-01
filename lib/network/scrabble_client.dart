typedef MessageReceivedCallback = void Function(String message);
typedef ConnectionClosedCallback = void Function();

abstract class ScrabbleClient {
  /// Connexion au serveur.
  Future<void> connect(String address, int port);

  /// Envoie un message au serveur
  void sendMessage(String message);

  /// Ferme proprement la connexion
  void disconnect();

  /// Callbacks
  set onMessageReceived(MessageReceivedCallback callback);
  set onConnectionClosed(ConnectionClosedCallback callback);
}
