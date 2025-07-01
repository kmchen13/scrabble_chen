import 'scrabble_server.dart';

// Exemple simplifié, à adapter avec ton RelayClient concret
class RelayScrabbleServer implements ScrabbleServer {
  late ClientConnectedCallback _onClientConnected;
  late ErrorCallback _onError;

  @override
  Future<void> start({
    required void Function(String) onClientConnected,
    required void Function(Object error) onError,
  }) async {
    _onClientConnected = onClientConnected;
    _onError = onError;

    try {
      // Exemple d'initialisation (adapter avec ton RelayClient réel)
      // await relayClient.connect();
      // relayClient.onMessageReceived = (msg) {
      //   if (msg.startsWith('USERNAME:')) {
      //     final username = msg.substring('USERNAME:'.length).trim();
      //     _onClientConnected(username);
      //   }
      // };
      // relayClient.onConnectionClosed = () {
      //   // Gérer la déconnexion si besoin
      // };
    } catch (e) {
      _onError(e);
    }
  }

  @override
  void sendToClient(String message) {
    // relayClient.sendMessage(message);
  }

  @override
  void stop() {
    // relayClient.disconnect();
  }
}
