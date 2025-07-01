// network/relay_client.dart
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'scrabble_client.dart';

class RelayScrabbleClient implements ScrabbleClient {
  late WebSocketChannel _channel;

  late MessageReceivedCallback _onMessageReceived;
  late ConnectionClosedCallback _onConnectionClosed;

  @override
  Future<void> connect(String address, int port) async {
    final uri = Uri.parse('ws://$address:$port');
    _channel = WebSocketChannel.connect(uri);

    _channel.stream.listen(
      (message) {
        _onMessageReceived(message);
      },
      onDone: () {
        _onConnectionClosed();
      },
      onError: (error) {
        _onConnectionClosed(); // Considère aussi l’erreur comme fermeture
      },
    );
  }

  @override
  void sendMessage(String message) {
    _channel.sink.add(message);
  }

  @override
  void disconnect() {
    _channel.sink.close(status.normalClosure);
  }

  @override
  set onMessageReceived(MessageReceivedCallback callback) {
    _onMessageReceived = callback;
  }

  @override
  set onConnectionClosed(ConnectionClosedCallback callback) {
    _onConnectionClosed = callback;
  }
}
