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
import 'package:scrabble_P2P/services/app_lifecycle.dart';
import 'scrabble_net.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/services/utility.dart';

class _GameStateDispatcher {
  GameState? pending;

  Future<void> handleIncoming(
    GameState state,
    void Function(GameState)? callback,
  ) async {
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

  // Cache pour éviter les doublons
  String? _lastProcessedGameId;
  DateTime? _lastProcessedTime;

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
  /// Récupère la liste des joueurs libres depuis le relay_server
  Future<List<Map<String, dynamic>>> getFreePlayers() async {
    try {
      final uri = Uri.parse('$_relayServerUrl/freeplayers');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['players']);
        }
      }
      return [];
    } catch (e) {
      print('[ScrabbleNet] Erreur getFreePlayers: $e');
      return [];
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
    } catch (e) {
      logger.e("Erreur envoi GameOver : $e");
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

  ///Attachement du callback pour GameOver
  @override
  void Function(GameState state)? get onGameOverReceived => _onGameOverReceived;
  GameState? _pendingGameOver;
  void Function(GameState state)? _onGameOverReceived;

  @override
  set onGameOverReceived(void Function(GameState state)? callback) {
    _onGameOverReceived = callback;

    print(
      "${logHeader("relayNet")} onGameOverReceived setter "
      "(hash=${callback?.hashCode})",
    );

    if (callback != null && _pendingGameOver != null) {
      final pending = _pendingGameOver!;
      _pendingGameOver = null;

      Future.microtask(() {
        callback(pending);
      });
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
              final gameState = GameState.fromJson(message);

              // 🔥 Utiliser gameId directement (non-nullable)
              final String stateId = gameState.gameId;
              final now = DateTime.now();

              if (debug) {
                print(
                  "${logHeader("relayNet")} GAMESTATE reçu de $partner (gameId=$stateId)",
                );
              }

              // 🔥 Vérifier les doublons
              if (_lastProcessedGameId == stateId &&
                  _lastProcessedTime != null &&
                  now.difference(_lastProcessedTime!) <
                      const Duration(seconds: 2)) {
                print('⚠️ Doublon détecté pour gameId: $stateId, ignoré');
                return;
              }

              // Mettre à jour le cache
              _lastProcessedGameId = stateId;
              _lastProcessedTime = now;

              // 🔐 Attendre que le traitement soit terminé
              await _dispatcher.handleIncoming(gameState, onGameStateReceived);

              // ✅ Jouer le son
              if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
                await _playNotificationSound();
              } else if (AppLifecycle.isForeground) {
                await _playNotificationSound();
              } else {
                final msg = "$partner a joué";
                await NotificationService.showGameMessage(msg);
              }

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
                  "dernier coup de la partie avec $partner. Celui qui a joué en deuxième joue le dernier coup";

              if (AppLifecycle.isForeground) {
                await _playNotificationSound();
              } else {
                await NotificationService.showGameMessage(msg);
              }

              _gameIsOver = true;

              final gameState = GameState.fromJson(message);

              // sauvegarde immédiate
              await gameStorage.save(gameState);

              // même pipeline que GAMESTATE
              if (_onGameOverReceived != null) {
                _onGameOverReceived!(gameState);
              }

              // ⚠️ surtout ne pas arrêter le polling ici
              // Le joueur droit doit recevoir son dernier tour
              // stopPolling();  <-- supprimer
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
              if (debug) {
                print("${logHeader("relayNet")} GAMEQUIT reçu de $partner");
              }

              // 🧹 suppression de la partie sauvegardée
              if (partner.isNotEmpty) {
                await gameStorage.delete(partner);
              }

              _gameIsOver = false;

              // 🔔 notification logique vers l'UI
              onGameQuitReceived?.call(partner);
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
              if (AppLifecycle.isForeground) {
                await _playNotificationSound();
              } else {
                await NotificationService.showGameMessage(msg);
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
  Future<void> sendGameQuit(me, partner) async {
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
  }

  void Function(String error)? onError;

  @override
  void Function(String message)? onStatusUpdate;

  @override
  void resetGameOver() {
    _gameIsOver = false;
  }

  void Function(String partner, String reason)? _onConnectionClosed;

  void Function(String partner)? onGameQuitReceived;

  @override
  void setOnConnectionClosed(
    void Function(String partner, String reason)? callback,
  ) {
    _onConnectionClosed = callback;
  }
}
