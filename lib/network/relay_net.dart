import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../services/log.dart';
import 'scrabble_net.dart';
import '../constants.dart';
import '../services/utility.dart';

class RelayNet implements ScrabbleNet {
  late final String _relayServerUrl;
  bool _gameIsOver = false;
  final _player = AudioPlayer();

  Future<void> _playNotificationSound() async {
    try {
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (e) {
      print('[${logHeader("relayNet")}] Erreur lecture son : $e');
    }
  }

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
    onStatusUpdate?.call("Connexion au serveur relai...");
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

      if (res.statusCode == 200) {
        onStatusUpdate?.call("Connecté...");
      } else {
        onStatusUpdate?.call("Erreur serveur (${res.statusCode})");
      }
      final json = jsonDecode(res.body);
      if (debug) {
        print(
          "[${logHeader("relayNet")}] Demande de connexion $localName → $expectedName : $startTime",
        );
        print("[${logHeader("relayNet")}] Réponse serveur: $json");
      }

      if (json['status'] == 'matched') {
        onStatusUpdate?.call("Partenaire trouvé (${json['partner']})");
        _isConnected = true;
        startPolling(localName);

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
        if (debug)
          print(
            "[${logHeader("relayNet")}] En attente de partenaire… démarrage du polling",
          );
        startPolling(localName);
      } else {
        if (debug)
          print(
            "[${logHeader("relayNet")}] Pas de match ni attente → retry dans $_retryDelay s",
          );
        Future.delayed(Duration(seconds: _retryDelay), () {
          connect(
            localName: localName,
            expectedName: expectedName,
            startTime: startTime,
          );
        });
      }
    } on SocketException {
      onStatusUpdate?.call(
        "Attente réponse serveur...Vérifiez que vous n'êtes pas en mode Avion",
      );
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

  @override
  void startPolling(String localName) {
    if (_pollingTimer != null) {
      if (debug)
        print(
          "[${logHeader("relayNet")}] Polling déjà actif (timer=${identityHashCode(_pollingTimer)})",
        );
      return; // n’en recrée pas un autre
    }
    if (debug)
      print('[${logHeader("relayNet")}] Polling démarré pour $localName');
    _pollingTimer = Timer.periodic(
      Duration(seconds: _timerFrequency),
      (_) async => await pollMessages(localName),
    );
  }

  // ⭐️ suspend explicitement
  void _pausePolling() {
    if (debug) print("[${logHeader("relayNet")}] ⏸️ Polling suspendu");
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ⭐️ reprend explicitement
  void _resumePolling(String localName) {
    if (debug) print("[${logHeader("relayNet")}] ▶️ Polling repris");
    startPolling(localName);
  }

  String partnerFromGameState(GameState state, String userName) {
    return state.leftName == userName ? state.rightName : state.leftName;
  }

  @override
  Future<void> sendGameState(GameState state) async {
    if (_gameIsOver) {
      logger.w("⚠️ Tentative d'envoi de GameState après fin de partie ignorée");
      return;
    }
    final String userName = settings.localUserName;
    try {
      final String to = partnerFromGameState(state, userName);
      final res = await http.post(
        Uri.parse("$_relayServerUrl/gamestate"),
        body: jsonEncode({
          'from': userName,
          'to': to,
          'type': 'gameState',
          'message': state.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final json = jsonDecode(res.body);
      if (json['status'] == 'sent') {
        print("[${logHeader("relayNet")}] ✅ GameState envoyé : $state");
        _resumePolling(userName);
      } else {
        logger.w(
          "⚠️ Erreur serveur envoi GameState from $userName to $to: $json",
        );
      }
    } catch (e) {
      logger.e("Erreur envoi GameState : $e");
    }
  }

  @override
  void Function(GameState)? onGameStateReceived;

  Future<void> pollMessages(String localName) async {
    // if (debug) print('[${logHeader("relayNet")}] Poll de $localName');
    try {
      final res = await http.get(
        Uri.parse("$_relayServerUrl/poll?userName=$localName"),
      );
      final json = jsonDecode(res.body);

      switch (json['type']) {
        case 'gameState':
          _playNotificationSound();
          if (debug)
            print('[${logHeader("relayNet")}] GameState reçu pour $localName');
          final dynamic msg = json['message'];
          final gameState = GameState.fromJson(msg);
          onGameStateReceived?.call(gameState);

          // ⭐️ stoppe le polling (on attend que le joueur joue)
          _pausePolling();
          break;

        case 'message':
          _playNotificationSound();
          if (debug)
            print(
              "[${logHeader("relayNet")}] Message reçu: ${json['message']}",
            );
          break;

        case 'matched':
          if (debug)
            print('[${logHeader("relayNet")}] Match trouvé pour $localName');
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
          // if (debug)
          //   print('[${logHeader("relayNet")}] [${logHeader("relayNet")}] "[${logHeader("relayNet")}] Aucun message pour $localName");
          break;

        case 'gameOver':
          _playNotificationSound();
          _gameIsOver = true;
          final gameState = GameState.fromJson(json['message']);
          if (debug)
            print('[${logHeader("relayNet")}] GameOver reçu pour $localName');
          onGameOverReceived?.call(gameState);

          // ⭐️ fin de partie → plus de polling
          _pausePolling();
          break;

        default:
          if (debug)
            print(
              "[${logHeader("relayNet")}] Type de message inconnu: ${json['type']}",
            );
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
      final res = await http.post(
        Uri.parse("$_relayServerUrl/gameover"), // ⭐️ endpoint dédié
        body: jsonEncode({
          'from': userName,
          'to': partnerFromGameState(finalState, userName),
          'type': 'gameOver',
          'message': finalState.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final json = jsonDecode(res.body);
      if (json['status'] == 'sent') {
        print("[${logHeader("relayNet")}] ✅ GameOver envoyé : $finalState");
      } else {
        logger.w("⚠️ Erreur serveur GameOver: $json");
      }

      _gameIsOver = true;

      // ⭐️ après avoir déclaré la fin, on ne redémarre PAS le polling
      _pausePolling();
    } catch (e) {
      logger.e("Erreur envoi GameOver : $e");
    }
  }

  @override
  void Function(GameState)? onGameOverReceived;

  @override
  Future<void> disconnect() async {
    try {
      _pausePolling();
      final String localName = settings.localUserName;
      await http.get(
        Uri.parse("$_relayServerUrl/disconnect?userName=$localName&partner="),
      );
    } catch (e) {
      logger.e("Erreur lors de la déconnexion : $e");
    } finally {
      _isConnected = false;
      onStatusUpdate?.call("Déconnecté");
    }
  }

  void Function(String error)? onError;

  @override
  void Function(String message)? onStatusUpdate;
}
