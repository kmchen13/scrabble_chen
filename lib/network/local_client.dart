import 'dart:convert';
import 'dart:io';

import 'scrabble_client.dart';

class LocalScrabbleClient implements ScrabbleClient {
  late Socket _socket;

  // Callbacks initialisés avec des fonctions vides par défaut
  MessageReceivedCallback _onMessageReceived = (String message) {};
  ConnectionClosedCallback _onConnectionClosed = () {};

  @override
  Future<void> connect(String address, int port) async {
    try {
      _socket = await Socket.connect(address, port);

      _socket
          .map((data) => data.toList()) // Conversion Uint8List -> List<int>
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              _onMessageReceived(line);
            },
            onDone: () {
              _onConnectionClosed();
            },
            onError: (error) {
              _onConnectionClosed();
            },
          );
    } catch (e) {
      rethrow;
    }
  }

  @override
  void sendMessage(String message) {
    _socket.writeln(message);
  }

  @override
  void disconnect() {
    _socket.close();
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
