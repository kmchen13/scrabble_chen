import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/assets_manager.dart';
import 'package:scrabble_P2P/services/log.dart';
import 'package:scrabble_P2P/services/notification.dart';
import 'scrabble_net.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/services/utility.dart';

class _GameStateDispatcher {
  GameState? pending;

  void handleIncoming(GameState state, void Function(GameState)? callback) {
    // 🔴 PERSISTANCE IMMÉDIATE (clé de tout)
    if (debug) print("${logHeader('handleIncoming')} Sauvegarde immédiate");
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

  GameState? _pendingGameState;
  bool _sendingPending = false;
  bool appInForeground = true;

  Future<void> _playNotificationSound() async {
    try {
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        await _player.play(
          DeviceFileSource(
            AssetManager.desktopPath('assets/sounds/notify.wav'),
          ),
        );
      } else {
        await _player.play(AssetSource('sounds/notify.wav'));
      }
    } catch (e) {
      print(
        '${logHeader("relayNet")} '
        'Erreur lecture son : $e',
      );
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
          'user': localName,
          'expectedName': expectedName,
          'startTime':
              startTime, //startTime est conservé pour compatibilité localNet
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

      if (json['status'] == 'MATCHED') {
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
      } else if (json['status'] == 'WAITING') {
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
          if (!_isConnected && !_retrying) {
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
    final String user = settings.localUserName;
    final String to = state.partnerFrom(user);

    final res = await http
        .post(
          Uri.parse("$_relayServerUrl/gamestate"),
          body: jsonEncode({
            'user': user,
            'partner': to,
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

    if (json['status'] != 'SENT') {
      if (debug) {
        print("${logHeader("relayNet")} ⚠️ serveur: ${json['status']}");
      }
    }

    return json['status'] == 'SENT';
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
    required int date,
    required Future<void> Function() handler,
  }) async {
    // 1️⃣ traiter / persister AVANT ack
    await handler();

    // 2️⃣ ACK seulement après succès
    final res = await http.get(
      Uri.parse(
        '$_relayServerUrl/acknowledgement'
        '?user=$localName&partner=$partner&type=$type&date=$date',
      ),
    );

    final json = jsonDecode(res.body);
    if (json['status'] != 'OK') {
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
        Uri.parse("$_relayServerUrl/poll?user=$localName"),
      );
    } catch (e) {
      logger.e("Erreur pollMessages: $e");
      return;
    }

    final json = jsonDecode(response.body);
    if (json['result'] == 'NO_MESSAGE') {
      return;
    }
    final String user = json['user'] ?? '';
    final String partner = json['partner'] ?? '';
    final String type = json['type'] ?? '';
    final String message = json['message'] ?? '';
    final int date = json['date'] ?? 0;

    try {
      switch (type) {
        case 'GAMESTATE':
          await _handleAndAck(
            localName: user,
            partner: partner,
            type: type,
            date: date,
            handler: () async {
              final msg = "$partner a joué";
              if (appInForeground) {
                _playNotificationSound();
              } else {
                NotificationService.showGameMessage(msg);
              }
              final gameState = GameState.fromJson(message);

              // 🔐 persistance immédiate
              _dispatcher.handleIncoming(gameState, onGameStateReceived);

              if (_gameIsOver) _gameIsOver = false;
            },
          );
          break;

        case 'GAMEOVER':
          await _handleAndAck(
            localName: user,
            partner: partner,
            type: type,
            date: date,
            handler: () async {
              final msg =
                  "derniers coups de la partie avec $partner. Celui qui a joué en deuxième joue le dernier coup";
              if (appInForeground) {
                _playNotificationSound();
              } else {
                NotificationService.showGameMessage(msg);
              }
              _gameIsOver = true;

              final gameState = GameState.fromJson(message);
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

        case 'MATCHED':
          await _handleAndAck(
            localName: user,
            partner: partner,
            type: type,
            date: date,
            handler: () async {
              _isConnected = true;

              onMatched?.call(
                leftName: partner,
                leftIP: '',
                leftPort: 0,
                leftStartTime: 0,
                rightName: localName,
                rightIP: '',
                rightPort: 0,
                rightStartTime: 0,
              );
            },
          );
          break;

        case 'GAMEQUIT':
          await _handleAndAck(
            localName: user,
            partner: partner,
            type: type,
            date: date,
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

        case 'CHAT':
          await _handleAndAck(
            localName: user,
            partner: partner,
            type: type,
            date: date,
            handler: () async {
              final msg = "$partner: $message";
              if (appInForeground) {
                _playNotificationSound();
              } else {
                NotificationService.showGameMessage(msg);
              }
              if (debug) {
                print("${logHeader("relayNet")} Message reçu: ${message}");
              }
            },
          );
          break;
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
    final String user = settings.localUserName;
    try {
      final res = await http.post(
        Uri.parse("$_relayServerUrl/gameover"), // ⭐️ endpoint dédié
        body: jsonEncode({
          'user': user,
          'partner': finalState.partnerFrom(user),
          'type': 'gameOver',
          'message': finalState.toJson(),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      final json = jsonDecode(res.body);
      if (json['status'] == 'SENT') {
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

  ///Déconnecter, ne plus faire partie de la liste des joueurs "libres" (en attente de n'importe quel joueur)
  @override
  Future<void> disconnect() async {
    try {
      final user = settings.localUserName;

      await http.get(Uri.parse('$_relayServerUrl/disconnect?user=$user'));

      if (debug) {
        print('[relayNet] disconnect envoyé pour $user');
      }
    } catch (e) {
      if (debug) {
        print('[relayNet] disconnect erreur: $e');
      }
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
        body: jsonEncode({'user': me, 'partner': partner}),
      );
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == 'QUIT_SUCCESS') {
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
