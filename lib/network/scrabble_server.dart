// scrabble_server.dart

typedef ClientConnectedCallback = void Function(String remoteUserName);
typedef ErrorCallback = void Function(Object error);

abstract class ScrabbleServer {
  Future<void> start({
    required void Function(String) onClientConnected,
    required void Function(Object error) onError,
  });

  void sendToClient(String message);
  void stop();
}
