import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/log.dart';
import 'scrabble_net.dart';
import '../constants.dart';
import 'package:scrabble_P2P/services/utility.dart';

class _GameStateDispatcher {
  GameState? pending;

  void handleIncoming(GameState state, void Function(GameState)? callback) {
    // 🔴 PERSISTANCE IMMÉDIATE (clé de tout)
    gameStorage.save(state);

    if (callback != null) {
      callback(state);
    } else {
      pending = state;
    }
  }

  void flush(void Function(GameState)? callback) {
    if (pending != null && callback != null) {
      final state = pending!;
      pending = null;
      callback(state);
    }
  }
}

class RelayNet implements ScrabbleNet {
  late final _GameStateDispatcher _dispatcher = _GameStateDispatcher();

  late final String _relayServerUrl;
  bool _gameIsOver = false;
  final _player = AudioPlayer();

  Future<void> _playNotificationSound() async {
    try {
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (e) {
      print('${logHeader("relayNet")} Erreur lecture son : $e');
    }
  }

  Timer? _pollingTimer;
  bool _isConnected = false;
  bool _retrying = false;
  int _timerFrequency = 2; // fréquence de polling en secondes
  int _retryDelay = 2; // fré&quence de retry connect si "waiting" ou erreur

  RelayNet() {
    _relayServerUrl = settings.relayServerUrl;
    print('[relayNet] constructor called id=${identityHashCode(this)}');
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
    if (_isConnected) {
      if (debug)
        print(
          "${logHeader("relayNet")} Déjà connecté, nouvelle tentative de connexion ignorée",
        );
      return;
    }
    onStatusUpdate?.call("Connexion au serveur relai $_relayServerUrl...");
    try {
      final res = await http.post(
        Uri.parse("$_relayServerUrl/connect"),
        body: jsonEncode({
          'userName': localName,
          'expectedName': expectedName,
          'startTime': startTime,
        }),
        headers: {'Content-Type': 'application/json'},
      );
      final json = jsonDecode(res.body);

      if (res.statusCode == 200) {
        onStatusUpdate?.call(
          "Connecté au serveur WEB relais $_relayServerUrl, en attente d'un joueur",
        );
      } else if (res.statusCode == 503) {
        onStatusUpdate?.call(
          "serveur WEB relais $_relayServerUrl, temporairement indisponible, Veuillez réessayer plus tard.",
        );
      } else {
        onStatusUpdate?.call("Erreur serveur inattendue(${res.statusCode})");
      }
      if (debug) {
        print(
          "${logHeader("relayNet")} Demande de connexion $localName → $expectedName : $startTime",
        );
        print("${logHeader("relayNet")} Réponse serveur: $json");
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
            "${logHeader("relayNet")} En attente de partenaire… démarrage du polling",
          );
        // 🔥 Ajout demandé : informer StartScreen
        onStatusUpdate?.call(
          "Connecté au serveur WEB relais $_relayServerUrl, en attente d'un partenaire...",
        );
        startPolling(localName);
      } else {
        if (debug)
          print(
            "${logHeader("relayNet")} Pas de réponse du serveur → retry dans $_retryDelay s",
          );
        Future.delayed(Duration(seconds: _retryDelay), () {
          if (!_isConnected && _retrying) {
            _retrying = true;
            connect(
              localName: localName,
              expectedName: expectedName,
              startTime: startTime,
            ).whenComplete(() => _retrying = false);
          }
        });
      }
    } on SocketException {
      onStatusUpdate?.call(
        "Attente réponse serveur $_relayServerUrl...Vérifiez que vous n'êtes pas en mode Avion",
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
          "${logHeader("relayNet")} Polling déjà actif (timer=${identityHashCode(_pollingTimer)})",
        );
      return; // n’en recrée pas un autre
    }
    if (debug)
      print('${logHeader("relayNet")} Polling démarré pour $localName');
    _pollingTimer = Timer.periodic(
      Duration(seconds: _timerFrequency),
      (_) async => await pollMessages(localName),
    );
  }

  @override
  // ⭐️ suspend explicitement
  void stopPolling() {
    if (debug) print("${logHeader("relayNet")} ⏸️ Polling suspendu");
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // ⭐️ reprend explicitement
  void _resumePolling(String localName) {
    if (debug) print("${logHeader("relayNet")} ▶️ Polling repris");
    startPolling(localName);
  }

  void _pauseConnecting() {
    if (debug) print("${logHeader("relayNet")} 🛑 Connecting suspendu");
    _retryDelay = 5;
    _retrying = false;
  }

  @override
  Future<void> sendGameState(GameState state) async {
    if (_gameIsOver) {
      logger.w("⚠️ Tentative d'envoi de GameState après fin de partie ignorée");
      return;
    }
    final String userName = settings.localUserName;
    try {
      final String to = state.partnerFrom(userName);
      if (debug)
        print("${logHeader("relayNet")} ▶️ Envoi gameState de $userName à $to");
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
        if (debug)
          print(
            "${logHeader("relayNet")} ✅ GameState envoyé de $userName à $to (hash=${state.hashCode})",
            // "${logHeader("relayNet")} ✅ GameState envoyé : ${state.toString()}",
          );
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

  // Implémentation du getter pour satisfaire l'interface
  @override
  void Function(GameState state)? get onGameStateReceived =>
      _onGameStateReceived;

  void Function(GameState state)? _onGameStateReceived;

  @override
  @override
  set onGameStateReceived(void Function(GameState state)? callback) {
    _onGameStateReceived = callback;
    print(
      "${logHeader("relayNet")} onGameStateReceived setter (hash=${callback?.hashCode})",
    );

    // 🔥 flush éventuel
    _dispatcher.flush(callback);
  }

  void _handleIncomingGameState(GameState state) {
    print("${logHeader("relayNet")} GameState reçu (hash=${state.hashCode})");

    _dispatcher.handleIncoming(state, _onGameStateReceived);
  }

  ///Attachement du callback pour GameOver
  @override
  void Function(GameState state)? get onGameOverReceived => _onGameOverReceived;
  GameState? _pendingGameOver;
  void Function(GameState state)? _onGameOverReceived;

  @override
  set onGameOverReceived(void Function(GameState state)? callback) {
    _onGameOverReceived = callback;
    print(
      "${logHeader("relayNet")} onGameOverReceived setter called (newHash=${callback?.hashCode}) for net=${hashCode}",
    );

    if (callback != null && _pendingGameOver != null) {
      if (debug)
        print(
          "${logHeader("relayNet")} ⚡ GameOver en attente détecté, exécution différée",
        );
    }
  }

  /// Permet de vider manuellement le buffer si un état était en attente
  void flushPending() {
    _dispatcher.flush(_onGameStateReceived);

    if (_pendingGameOver != null && _onGameOverReceived != null) {
      final state = _pendingGameOver!;
      _pendingGameOver = null;
      _onGameOverReceived?.call(state);
    }
  }

  Future<void> pollMessages(String localName) async {
    // if (debug) print('${logHeader("relayNet")} Poll de $localName');
    final res = await http.get(
      Uri.parse("$_relayServerUrl/poll?userName=$localName"),
    );
    final json = jsonDecode(res.body);
    final String partner = json['from'] ?? json['partner'] ?? '';

    try {
      switch (json['type']) {
        case 'gameState':
          //@todo si le gamestate d'un autre partie, la stocker.
          _playNotificationSound();
          if (debug)
            print(
              '${logHeader("relayNet")} GameState reçu pour $localName in net instance ${identityHashCode(this)}; about to call onGameStateReceived (hash=${onGameStateReceived?.hashCode})',
            );
          final dynamic msg = json['message'];
          final gameState = GameState.fromJson(msg);
          stopPolling();
          _handleIncomingGameState(gameState);

          if (_gameIsOver) {
            _gameIsOver = false;
            logger.i(
              "🔁 Nouveau GameState reçu → réinitialisation _gameIsOver=false",
            );
          }
          if (debug) {
            print(
              "[relayNet] about to call onGameStateReceived "
              "(hash=${onGameStateReceived.hashCode})",
            );
          }
          break;

        case 'message':
          _playNotificationSound();
          if (debug)
            print("${logHeader("relayNet")} Message reçu: ${json['message']}");
          break;

        case 'matched':
          _isConnected = true;
          if (debug)
            print('${logHeader("relayNet")} Match trouvé pour $localName');
          final localTime = json['startTime'] ?? 0;
          final partnerTime = json['partnerStartTime'] ?? 0;
          if (localTime > partnerTime) {
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
          } else {
            onMatched?.call(
              leftName: json['partner'],
              leftIP: '',
              leftPort: 0,
              leftStartTime: json['partnerStartTime'] ?? 0,
              rightName: localName,
              rightIP: '',
              rightPort: 0,
              rightStartTime: json['startTime'] ?? 0,
            );
          }
          break;

        case 'no_message':
          // if (debug)
          //   print('${logHeader("relayNet")} ${logHeader("relayNet")} "${logHeader("relayNet")} Aucun message pour $localName");
          return;

        case 'quit':
          disconnect();
          _gameIsOver = false;
          onConnectionClosed?.call();
          break;

        case 'gameOver':
          if (debug)
            print(
              '${logHeader("relayNet")} onGameOverReceived? = ${onGameOverReceived != null}, net hashCode = ${this.hashCode}, GameOver reçu pour $localName',
            );
          _playNotificationSound();
          _gameIsOver = true;

          final gameState = GameState.fromJson(json['message']);

          if (_onGameOverReceived != null) {
            _onGameOverReceived!(gameState);
          } else {
            _pendingGameOver = gameState; // stocke si callback non attaché
          }

          // ⭐️ fin de partie → plus de polling
          stopPolling();
          break;

        case 'error':
          if (debug)
            print('${logHeader("relayNet")} /poll error: ${json['message']}');
          return;

        default:
          if (debug)
            print(
              "${logHeader("relayNet")} Type de message inconnu: ${json['type']}",
            );
          return;
      }

      //send acknowledgement
      final res = await http.get(
        Uri.parse(
          '$_relayServerUrl/acknowledgement?userName=$localName&partner=$partner&type=${json['type']}',
        ),
      );
      final jsonResponse = jsonDecode(res.body);
      if (debug)
        print('${logHeader("relayNet")} ack $localName-$partner envoyé');

      if (jsonResponse['status'] != 'ok') {
        print('${logHeader("relayNet")} erreur serveur traitement ack');
      }
    } catch (e, st) {
      if (debug) {
        logger.e("Erreur pollMessages : $e\n$st");
        print("message reçu: ${json}");
        print("type reçu: ${json['type']}");
      }
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
          'to': finalState.partnerFrom(userName),
          'type': 'gameOver',
          'message': finalState.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final json = jsonDecode(res.body);
      if (json['status'] == 'sent') {
        print("${logHeader("relayNet")} ✅ GameOver envoyé : $finalState");
      } else {
        logger.w("⚠️ Erreur serveur GameOver: $json");
      }

      _gameIsOver = true;

      // ⭐️ après avoir déclaré la fin, on ne redémarre PAS le polling
      stopPolling();
    } catch (e) {
      logger.e("Erreur envoi GameOver : $e");
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      _pauseConnecting();

      print("${logHeader("relayNet")} ✅ recherche de joueurs suspendue");
    } catch (e) {
      logger.e("Erreur lors de la déconnexion : $e");
    } finally {
      _isConnected = false;
    }
  }

  ///Quitte une partie
  @override
  Future<void> quit(me, partner) async {
    try {
      final url = Uri.parse("$_relayServerUrl/quit");
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userName': me, 'partner': partner}),
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'quit_success') {
          onStatusUpdate?.call('Vous avez quitté la partie avec $partner');
          _gameIsOver = false;
          if (debug)
            print("[relayNet] 🛑 Quit successful for $me (partner=$partner)");
        } else {
          if (debug)
            print("[relayNet] ⛔ Quit failed for $me (partner=$partner): $json");
        }
      } else {
        print("[relayNet] ⛔ Erreur abandon status code: ${res.statusCode}");
      }
    } catch (e) {
      if (debug) print("[relayNet] ⛔ Erreur abandon inattendue: $e");
    }

    disconnect();
  }

  void Function(String error)? onError;

  @override
  void Function(String message)? onStatusUpdate;

  @override
  void resetGameOver() {
    _gameIsOver = false;
  }

  @override
  void Function()? onConnectionClosed;
}
