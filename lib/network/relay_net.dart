import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../services/log.dart';
import 'scrabble_net.dart';
import '../constants.dart';

class RelayNet implements ScrabbleNet {
  late final String _relayServerUrl;
  Timer? _pollingTimer;
  bool _isConnected = false;
  final int _timerFrequency = 2; // fréquence de polling en secondes
  final int _retryDelay = 2; // délai de retry si "waiting" ou erreur

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
      if (debug) {
        logger.i(
          "Demande de connexion $localName → $expectedName : $startTime",
        );
        logger.i("Réponse serveur: $json");
      }

      if (json['status'] == 'matched') {
        _isConnected = true;
        _startPolling(localName);

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
      } else if (json['status'] == 'waiting') {
        if (debug) logger.i("En attente de partenaire… démarrage du polling");
        _startPolling(localName);
      } else {
        // Si ce n’est ni waiting ni matched → on retente
        if (debug)
          logger.i("Pas de match ni attente → retry dans $_retryDelay s");
        Future.delayed(Duration(seconds: _retryDelay), () {
          connect(
            localName: localName,
            expectedName: expectedName,
            startTime: startTime,
          );
        });
      }
    } catch (e) {
      logger.e("Erreur lors de la connexion : $e\nurl: $_relayServerUrl");
      Future.delayed(Duration(seconds: _retryDelay), () {
        connect(
          localName: localName,
          expectedName: expectedName,
          startTime: startTime,
        );
      });
    }
  }

  void _startPolling(String localName) {
    if (debug) logger.i('Polling started for $localName');
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

  @override
  void Function(GameState)? onGameStateReceived;

  Future<void> pollMessages(String localName) async {
    if (debug) logger.i('Poll de $localName');
    try {
      final res = await http.get(
        Uri.parse("$_relayServerUrl/poll?userName=$localName"),
      );
      final json = jsonDecode(res.body);

      switch (json['type']) {
        case 'gameState':
          if (debug) logger.i('GameState reçu pour $localName');
          final dynamic msg = json['message'];
          final gameState = GameState.fromJson(msg);
          onGameStateReceived?.call(gameState);
          break;

        case 'message':
          if (debug) logger.i("Message reçu: ${json['message']}");
          break;

        case 'matched':
          if (debug) logger.i('Match trouvé pour $localName');
          _isConnected = true;
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
          if (debug) logger.i("Aucun message pour $localName");
          break;

        case 'gameOver':
          final gameState = GameState.fromJson(json['message']);
          if (debug) logger.i('GameOver reçu pour $localName');
          onGameOverReceived?.call(gameState);
          break;

        default:
          if (debug) logger.i("Type de message inconnu: ${json['type']}");
          break;
      }
    } catch (e, st) {
      logger.e("Erreur pollMessages : $e\n$st");
    }
  }

  @override
  void sendGameOver(GameState finalState) async {
    final String userName = settings.localUserName;
    try {
      await http.post(
        Uri.parse("$_relayServerUrl/gamestate"),
        body: jsonEncode({
          'from': userName,
          'to': partnerFromGameState(finalState, userName),
          'type': 'gameOver',
          'message': finalState.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
      logger.i("GameOver envoyé : $finalState");
    } catch (e) {
      logger.e("Erreur envoi GameOver : $e");
    }
  }

  @override
  void Function(GameState)? onGameOverReceived;

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
