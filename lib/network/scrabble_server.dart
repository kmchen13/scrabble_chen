// scrabble_server.dart
import 'dart:async';

import '../services/settings_service.dart';
import '../network/relay_server.dart';
import '../network/local_server.dart';

abstract class ScrabbleServer {
  Future<void> start({
    required void Function(String clientUserName) onClientConnected,
    required void Function(Object error) onError,
  });

  void sendToClient(String message);
  void stop();

  static Future<ScrabbleServer> create({
    required String localUserName,
    required String? expectedClientUserName,
    required void Function(String clientUserName) onClientConnected,
    required void Function(Object error) onError,
  }) async {
    final mode = settings.communicationMode;

    if (mode == 'web') {
      final server = RelayScrabbleServer(
        localUserName: localUserName,
        expectedClientUserName: expectedClientUserName,
      );
      await server.start(
        onClientConnected: onClientConnected,
        onError: onError,
      );
      return server;
    } else {
      final server = LocalScrabbleServer(
        localUserName: localUserName,
        expectedClientUserName: expectedClientUserName,
      );
      await server.start(
        onClientConnected: onClientConnected,
        onError: onError,
      );
      return server;
    }
  }
}
