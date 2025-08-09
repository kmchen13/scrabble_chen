import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../services/utility.dart';
import '../services/log.dart';
import 'scrabble_net.dart';

/*
 *  RelayNet is a class that implements the ScrabbleNet interface
 *  for relay server communication using WebSockets.
 *  It handles player matching and game state transmission through a relay server.
 * Connection starts with a WebSocket connection to the relay server mentioning its userName, expectedPartner. Server adds startTime.
 * When a match occurs between two players, the relay server sends the match information to relaNet. Then relayNet triggers startScreen onMatched callback.
 * 
 */

class RelayNet implements ScrabbleNet {
  // String _relayServerUrl = "ws://170.253.40.247:8083/ws";
  // String _relayServerUrl = "ws://192.168.1.155:8080/ws";
  // String _relayServerUrl = "wss://relay-server-3lv4.onrender.com";
  late final String _relayServerUrl;

  WebSocketChannel? _channel;
  bool _connected = false;
  bool _debug = true;

  RelayNet() {
    _relayServerUrl = settings.relayServerUrl;
  }

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
    if (_debug)
      logger.i(
        '${logHeader("RelaylNet")} Connexion à $_relayServerUrl : $localName : $expectedName : $startTime',
      );
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_relayServerUrl));
      _connected = true;
      logger.d("Connexion réussie");
    } catch (e, st) {
      logger.e("Erreur de connexion", error: e, stackTrace: st);
    }

    Timer.periodic(const Duration(seconds: 30), (_) {
      if (_connected) {
        _channel?.sink.add(
          jsonEncode({
            'type': 'keepalive',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        );
      }
    });

    _channel!.stream.listen((data) {
      if (_debug) logger.i('${logHeader("RelaylNet")} Message reçu: $data');

      try {
        final Map<String, dynamic> decoded =
            jsonDecode(data) as Map<String, dynamic>;

        switch (decoded['type']) {
          case 'matched':
            _handleMatch(Map<String, dynamic>.from(decoded));
            break;
          case 'gameState':
            final gameState = GameState.fromJson(jsonEncode(decoded['data']));
            onGameStateReceived?.call(gameState);
            break;
        }
      } catch (e) {
        if (_debug)
          logger.i('${logHeader("RelaylNet")} Erreur parsing JSON: $e');
      }
    });

    // Envoyer une demande de matchmaking
    final connectMsg = jsonEncode({
      'type': 'connect',
      'userName': localName,
      'expectedName': expectedName,
      'startTime': startTime,
    });
    _channel!.sink.add(connectMsg);
  }

  void _handleMatch(Map<String, dynamic> message) {
    try {
      final leftName = message['leftName'] as String;
      final leftStartTime = message['leftStartTime'] as int;
      final rightName = message['rightName'] as String;
      final rightStartTime = message['rightStartTime'] as int;

      onMatched?.call(
        leftName: leftName,
        leftIP: '',
        leftPort: 0,
        leftStartTime: leftStartTime,
        rightName: rightName,
        rightIP: '',
        rightPort: 0,
        rightStartTime: rightStartTime,
      );
    } catch (e) {
      logger.i('${logHeader("RelayNet")} Erreur parsing match: $e');
    }
  }

  @override
  void sendGameState(GameState state) {
    if (!_connected || _channel == null) {
      if (_debug) logger.i('${logHeader("RelaylNet")} ⚠️ Pas connecté');
      return;
    }
    final jsonString = jsonEncode({
      'type': 'gameState',
      'data': state.toJson(),
    });
    _channel!.sink.add(jsonString);
    if (_debug)
      logger.i('${logHeader("RelaylNet")} GameState envoyé: ${state.toJson()}');
  }

  @override
  void disconnect() {
    _connected = false;
    _channel?.sink.close();
    _channel = null;
    if (_debug) logger.i('${logHeader("RelaylNet")} Déconnecté');
  }

  void Function(String error)? onError;
}
