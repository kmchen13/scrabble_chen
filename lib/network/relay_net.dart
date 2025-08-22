import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../services/log.dart';
import '../services/utility.dart';
import 'scrabble_net.dart';

class RelayNet implements ScrabbleNet {
  late final String _relayServerUrl;
  final bool _debug = true;
  Timer? _pollingTimer;
  bool _isConnected = false;
  final int _timerFrequency = 2; // fréquence de polling en secondes

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
    try {
      final res = await http.post(
        Uri.parse("$_relayServerUrl/register"),
        body: jsonEncode({
          'userName': localName,
          'expectedName': expectedName,
          'startTime': startTime,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final json = jsonDecode(res.body);
      if (_debug) {
        logger.i(
          "Demande de connexion $localName → $expectedName : $startTime",
        );
      }

      // démarrer le polling continu pour recevoir les réponses
      _startPolling(localName);

      if (json['status'] == 'matched') {
        _isConnected = true;

        onMatched?.call(
          leftName: localName,
          leftIP: '',
          leftPort: 0,
          leftStartTime: startTime,
          rightName: json['partner'],
          rightIP: '',
          rightPort: 0,
          rightStartTime: json['partnerStartTime'] ?? startTime,
        );
      }
    } catch (e) {
      logger.e("Erreur lors de la connexion : $e\nurl: $_relayServerUrl");
    }
  }

  void _startPolling(String localName) {
    if (_debug) print('Polling started for $localName');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      Duration(seconds: _timerFrequency),
      (_) async => await pollMessages(localName),
    );
  }

  String partnerFromGameState(GameState state, String userName) {
    return state.leftName == userName ? state.rightName : state.leftName;
  }

  @override
  Future<void> sendGameState(GameState state) async {
    final String userName = settings.localUserName;
    try {
      await http.post(
        Uri.parse("$_relayServerUrl/gamestate"),
        body: jsonEncode({
          'from': userName,
          'to': partnerFromGameState(state, userName),
          'type': 'gameState',
          'message': state.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
      logger.i("GameState envoyé : $state");
    } catch (e) {
      logger.e("Erreur envoi GameState : $e");
    }
  }

  Future<void> pollMessages(String localName) async {
    if (_debug) print('Poll de $localName');
    try {
      final res = await http.get(
        Uri.parse("$_relayServerUrl/poll?userName=$localName"),
      );
      final json = jsonDecode(res.body);

      switch (json['type']) {
        case 'gameState':
          if (_debug) print('GameState reçu pour $localName');
          final dynamic msg = json['message'];
          final gameState = GameState.fromJson(msg);

          onGameStateReceived?.call(gameState);
          break;

        case 'message':
          if (_debug) print("Message reçu: ${json['message']}");
          break;

        case 'matched':
          if (_debug) print('Match trouvé pour $localName');
          onMatched?.call(
            leftName: localName,
            leftIP: '',
            leftPort: 0,
            leftStartTime: json['startTime'] ?? 0,
            rightName: json['partner'],
            rightIP: '',
            rightPort: 0,
            rightStartTime: json['partnerStartTime'] ?? 0,
          );
          break;

        case 'no_message':
          if (_debug) print("Aucun message pour $localName");
          break;

        default:
          if (_debug) print("Type de message inconnu: ${json['type']}");
          break;
      }
    } catch (e, st) {
      logger.e("Erreur pollMessages : $e\n$st");
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      final String localName = settings.localUserName;
      await http.get(
        Uri.parse("$_relayServerUrl/disconnect?userName=$localName&partner="),
      );
    } catch (e) {
      logger.e("Erreur lors de la déconnexion : $e");
    } finally {
      _isConnected = false;
      _pollingTimer?.cancel();
      _pollingTimer = null;
    }
  }

  void Function(String error)? onError;
}
