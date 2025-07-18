import 'dart:convert';
import 'dart:io';

import '../models/game_state.dart';
import '../services/settings_service.dart';
import 'scrabble_net.dart';

class RelayNet implements ScrabbleNet {
  Socket? _socket;

  @override
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

  @override
  void Function(GameState)? onGameStateReceived;

  @override
  Future<void> connect({
    required String localName,
    required String expectedName,
    required int startTime,
  }) async {
    final relayIP = settings.relayAddress;
    final relayPort = settings.relayPort;

    try {
      _socket = await Socket.connect(relayIP, relayPort);
    } catch (e) {
      print('[RelayNet] Connexion échouée : $e');
      return;
    }

    // Envoie l’identifiant local au serveur relais
    final connectMessage = jsonEncode({
      'type': 'connect',
      'localName': localName,
      'rightName': expectedName,
    });
    _socket!.writeln(connectMessage);

    // Écoute les messages en provenance du serveur relais
    _socket!.listen(
      (data) {
        final message = utf8.decode(data).trim();
        final decoded = jsonDecode(message);

        switch (decoded['type']) {
          case 'matched':
            if (onMatched != null) {
              onMatched!(
                leftName: decoded['leftName'],
                leftIP: decoded['leftIP'],
                leftPort: decoded['leftPort'],
                leftStartTime: decoded['leftStartTime'],
                rightName: decoded['rightName'],
                rightIP: decoded['rightIP'],
                rightPort: decoded['rightPort'],
                rightStartTime: decoded['rightStartTime'],
              );
            }
            break;

          case 'gamestate':
            try {
              final gameState = GameState.fromJson(message);
              onGameStateReceived?.call(gameState);
            } catch (_) {
              print('[RelayNet] GameState invalide');
            }
            break;
        }
      },
      onDone: disconnect,
      onError: (e) {
        print('[RelayNet] Erreur: $e');
        disconnect();
      },
    );
  }

  @override
  void sendGameState(GameState state) {
    final message = state.toJson();
    _socket?.writeln(message);
  }

  void disconnect() {
    _socket?.destroy();
    _socket = null;
  }
}
