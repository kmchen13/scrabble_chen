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
    if (debug) print("${logHeader('handleIncoming')} Sauvegarde immédiate");
    gameStorage.save(state);

    // ⚡ Toujours notifier l'UI
    if (callback != null) {
      callback(state);
    }

    // ⚡ Conserver pour flush si jamais callback était null à ce moment
    pending = state;
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

  GameState? _pendingGameState;
  bool _sendingPending = false;

  @override
  Future<void> init() async {
    _pendingGameState = gameStorage.loadPendingGameState();

    if (_pendingGameState != null && debug) {
      print(
        "${logHeader("relayNet")} 🔁 GameState pending restauré "
        "(hash=${_pendingGameState!.hashCode})",
      );
    }
  }

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
  int _timerFrequency = 5; // fréquence de polling en secondes
  int _retryDelay = 5; // fré&quence de retry connect si "waiting" ou erreur

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
    // if (_isConnected) {
    //   if (debug)
    //     print(
    //       "${logHeader("relayNet")} Déjà connecté, nouvelle tentative de connexion ignorée",
    //     );
    //   return;
    // }
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
    _pollingTimer = Timer.periodic(Duration(seconds: _timerFrequency), (
      _,
    ) async {
      try {
        await pollMessages(localName);
      } catch (e) {
        // Log l'erreur et la stack trace pour le débogage
        if (debug) {
          print("${logHeader('pollMessages')} ⚠️ Erreur lors du polling: $e");
        }
        // Vous pouvez aussi ajouter une logique de relance ou de notification ici
      }
    });
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

  Future<bool> _sendGameStateToServer(GameState state) async {
    final String userName = settings.localUserName;
    final String to = state.partnerFrom(userName);

    final res = await http
        .post(
          Uri.parse("$_relayServerUrl/gamestate"),
          body: jsonEncode({
            'from': userName,
            'to': to,
            'type': 'gameState',
            'message': state.toJson(),
          }),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      return false;
    }

    final json = jsonDecode(res.body);

    if (json['status'] != 'sent') {
      if (debug) {
        print("${logHeader("relayNet")} ⚠️ serveur: ${json['status']}");
      }
    }

    return json['status'] == 'sent';
  }

  Future<void> retryPendingGameState() async {
    if (_pendingGameState == null) return;
    if (_sendingPending) return;

    _sendingPending = true;

    try {
      final ok = await _sendGameStateToServer(_pendingGameState!);

      if (ok) {
        if (debug) {
          print("${logHeader("relayNet")} 🔁 GameState en attente envoyé");
        }

        _pendingGameState = null;
        await gameStorage.clearPendingGameState();
      }
    } catch (e) {
      if (debug) {
        print("${logHeader("relayNet")} ⚠️ Retry échoué: $e");
      }
    } finally {
      _sendingPending = false;
    }
  }

  @override
  Future<void> sendGameState(GameState state) async {
    if (_pendingGameState != null && !_sendingPending) {
      await retryPendingGameState();
    }
    if (_gameIsOver) {
      logger.w("⚠️ Tentative d'envoi de GameState après fin de partie ignorée");
      return;
    }

    try {
      final ok = await _sendGameStateToServer(state);

      if (ok) {
        if (debug) {
          print(
            "${logHeader("relayNet")} ✅ GameState envoyé (hash=${state.hashCode})",
          );
        }

        _pendingGameState = null;
        _resumePolling(settings.localUserName);
      } else {
        throw Exception("Server refused gamestate");
      }
    } catch (e) {
      logger.w("⚠️ Réseau indisponible, GameState mis en attente");

      // garder seulement le dernier state
      _pendingGameState = state;
      await gameStorage.savePendingGameState(state);
    }
  }

  // Implémentation du getter pour satisfaire l'interface
  @override
  void Function(GameState state)? get onGameStateReceived =>
      _onGameStateReceived;

  void Function(GameState state)? _onGameStateReceived;

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

  Future<void> _handleAndAck({
    required String localName,
    required String partner,
    required String type,
    required Future<void> Function() handler,
  }) async {
    // 1️⃣ traiter / persister AVANT ack
    await handler();

    // 2️⃣ ACK seulement après succès
    final res = await http.get(
      Uri.parse(
        '$_relayServerUrl/acknowledgement'
        '?userName=$localName&partner=$partner&type=$type',
      ),
    );

    final json = jsonDecode(res.body);
    if (json['status'] != 'ok') {
      logger.w('[relayNet] ACK échoué pour type=$type');
    } else if (debug) {
      print('${logHeader("relayNet")} ack $type envoyé');
    }
  }

  Future<void> pollMessages(String localName) async {
    http.Response? response;
    // if (debug) print('${logHeader("relayNet")} Poll de $localName');

    await retryPendingGameState();

    try {
      response = await http.get(
        Uri.parse("$_relayServerUrl/poll?userName=$localName"),
      );
    } catch (e) {
      logger.e("Erreur pollMessages: $e");
      return;
    }

    final json = jsonDecode(response.body);
    final String partner = json['from'] ?? json['partner'] ?? '';
    bool shouldAck = false;

    try {
      switch (json['type']) {
        case 'gameState':
          await _handleAndAck(
            localName: localName,
            partner: partner,
            type: 'gameState',
            handler: () async {
              _playNotificationSound();
              final gameState = GameState.fromJson(json['message']);

              // 🔐 persistance immédiate
              _dispatcher.handleIncoming(gameState, onGameStateReceived);
              _dispatcher.flush(onGameStateReceived);

              if (_gameIsOver) _gameIsOver = false;
            },
          );
          break;

        case 'gameOver':
          await _handleAndAck(
            localName: localName,
            partner: partner,
            type: 'gameOver',
            handler: () async {
              _playNotificationSound();
              _gameIsOver = true;

              final gameState = GameState.fromJson(json['message']);
              gameStorage.save(gameState); // 🔐 CRUCIAL

              if (_onGameOverReceived != null) {
                _onGameOverReceived!(gameState);
              } else {
                _pendingGameOver = gameState;
              }

              stopPolling();
            },
          );
          break;

        case 'matched':
          await _handleAndAck(
            localName: localName,
            partner: partner,
            type: 'matched',
            handler: () async {
              _isConnected = true;

              final localTime = json['startTime'] ?? 0;
              final partnerTime = json['partnerStartTime'] ?? 0;

              onMatched?.call(
                leftName: localTime > partnerTime ? localName : json['partner'],
                leftIP: '',
                leftPort: 0,
                leftStartTime:
                    localTime > partnerTime ? localTime : partnerTime,
                rightName:
                    localTime > partnerTime ? json['partner'] : localName,
                rightIP: '',
                rightPort: 0,
                rightStartTime:
                    localTime > partnerTime ? partnerTime : localTime,
              );
            },
          );
          break;

        case 'quit':
          await _handleAndAck(
            localName: localName,
            partner: partner,
            type: 'quit',
            handler: () async {
              if (partner.isNotEmpty) {
                await gameStorage.delete(partner);
              }

              disconnect();
              _gameIsOver = false;
              _onConnectionClosed?.call(
                partner,
                "$partner a quitté la partie.",
              );
            },
          );
          break;

        case 'message':
          await _handleAndAck(
            localName: localName,
            partner: partner,
            type: 'message',
            handler: () async {
              _playNotificationSound();
              if (debug) {
                print(
                  "${logHeader("relayNet")} Message reçu: ${json['message']}",
                );
              }
            },
          );
          break;

        case 'no_message':
          return;
      }

      //send acknowledgement
      if (!shouldAck) return;
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

  void Function(String partner, String reason)? _onConnectionClosed;

  @override
  void setOnConnectionClosed(
    void Function(String partner, String reason)? callback,
  ) {
    _onConnectionClosed = callback;
  }
}
