import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/game_callback_manager.dart';
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
    if (debug)
      print(
        "${logHeader('relayNet.handleIncoming')} Appel du callback pour gameId=${state.gameId} (hash=${state.hashCode}) avec callback=${callback?.hashCode})",
      );

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

  // Pour les GameOver en attente (en mémoire + persistance)
  GameState? _pendingGameOver;
  bool _sendingGameOver = false;

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
  int _timerFrequency = 5;
  int _retryDelay = 5;

  RelayNet() {
    _relayServerUrl = settings.relayServerUrl;
    print('[relayNet] constructor called id=${identityHashCode(this)}');
    // Tenter d'envoyer tous les pending au démarrage
    Future.delayed(Duration(seconds: 1), () async {
      await _resumeAllPendingGameOver();
      await _resumeAllPendingGameStates();
    });
  }

  // ==================== Persistance GameState ====================
  Future<void> _savePendingGameState(GameState state) async {
    try {
      await gameStorage.savePending(state);
    } catch (e) {
      logger.w("Erreur sauvegarde pending: $e");
    }
  }

  Future<void> _clearPendingGameState(GameState state) async {
    try {
      await gameStorage.deletePending(state);
    } catch (e) {
      logger.w("Erreur suppression pending: $e");
    }
  }

  Future<void> _clearAllPendingGameStates() async {
    try {
      await gameStorage.deleteAllPending();
    } catch (e) {
      logger.w("Erreur suppression tous pending: $e");
    }
  }

  Future<void> _resumeAllPendingGameStates() async {
    if (_sendingPending) return;
    try {
      final all = await gameStorage.loadAllPending();
      for (final state in all) {
        // On utilise sendGameState qui gère les retries et la mise à jour de _pendingGameState
        await sendGameState(state);
      }
    } catch (e) {
      logger.w("Erreur résumé GameState pending: $e");
    }
  }

  // ==================== Persistance GameOver ====================
  Future<void> _savePendingGameOver(GameState state) async {
    try {
      await gameStorage.savePendingGameOver(state);
    } catch (e) {
      logger.w("Erreur sauvegarde gameover: $e");
    }
  }

  Future<void> _clearPendingGameOver(GameState state) async {
    try {
      await gameStorage.deletePendingGameOver(state);
    } catch (e) {
      logger.w("Erreur suppression gameover: $e");
    }
  }

  Future<void> _clearAllPendingGameOver() async {
    try {
      await gameStorage.deleteAllPendingGameOver();
    } catch (e) {
      logger.w("Erreur suppression tous gameover: $e");
    }
  }

  Future<void> _resumeAllPendingGameOver() async {
    if (_sendingGameOver) return;
    try {
      final all = await gameStorage.loadAllPendingGameOver();
      for (final state in all) {
        // On utilise sendGameOver qui gère les retries et la persistance
        await sendGameOver(state);
      }
    } catch (e) {
      logger.w("Erreur résumé GameOver pending: $e");
    }
  }

  // ==================== Fin persistance ====================

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
    // Nettoyer tous les pending (nouvelle partie)
    await _clearAllPendingGameStates();
    await _clearAllPendingGameOver();
    _pendingGameState = null;
    _pendingGameOver = null;

    onStatusUpdate?.call("Connexion au serveur relai $_relayServerUrl...");
    try {
      final res = await http.post(
        Uri.parse("$_relayServerUrl/connect"),
        body: jsonEncode({
          'user': localName,
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
      return;
    }
    if (debug)
      print('${logHeader("relayNet")} Polling démarré pour $localName');
    _pollingTimer = Timer.periodic(Duration(seconds: _timerFrequency), (
      _,
    ) async {
      try {
        await pollMessages(localName);
      } catch (e) {
        if (debug) {
          print("${logHeader('pollMessages')} ⚠️ Erreur lors du polling: $e");
        }
      }
    });
  }

  @override
  void stopPolling() {
    if (debug) print("${logHeader("relayNet")} ⏸️ Polling suspendu");
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _resumePolling(String localName) {
    if (debug) print("${logHeader("relayNet")} ▶️ Polling repris");
    startPolling(localName);
  }

  Future<bool> _sendGameStateToServer(GameState state) async {
    final String user = settings.localUser;
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
    if (_gameIsOver) return;
    if (_sendingPending) return;

    _sendingPending = true;

    try {
      final ok = await _sendGameStateToServer(_pendingGameState!);

      if (ok) {
        if (debug) {
          print("${logHeader("relayNet")} 🔁 GameState en attente envoyé");
        }
        _pendingGameState = null;
        // Pas besoin de supprimer la persistance ici, car sendGameState l'a déjà fait
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
  Future<List<Map<String, dynamic>>> getFreePlayers() async {
    try {
      final uri = Uri.parse('$_relayServerUrl/freeplayers');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(data['players']);
        }
      }
      throw NetworkException('Le réseau ne répond pas');
    } catch (e) {
      print('[ScrabbleNet] Erreur getFreePlayers: $e');
      throw NetworkException('Le réseau ne répond pas');
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
        // Supprimer la sauvegarde pour ce partenaire
        await _clearPendingGameState(state);
        _resumePolling(settings.localUser);
      } else {
        throw Exception("Server refused gamestate");
      }
    } catch (e) {
      logger.w("⚠️ Réseau indisponible, GameState mis en attente");
      // Garder en mémoire
      _pendingGameState = state;
      // Persister
      await _savePendingGameState(state);
    }
  }

  @override
  Future<void> sendGameOver(GameState finalState) async {
    final String user = settings.localUser;
    // Nettoyer le GameState en attente pour ce partenaire (la partie est finie)
    _pendingGameState = null;
    await _clearPendingGameState(finalState);

    if (_sendingGameOver) return;
    _sendingGameOver = true;

    try {
      final res = await http
          .post(
            Uri.parse("$_relayServerUrl/gameover"),
            body: jsonEncode({
              'user': user,
              'partner': finalState.partnerFrom(user),
              'type': 'gameOver',
              'message': finalState.toJson(),
            }),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));

      final json = jsonDecode(res.body);
      if (res.statusCode == 200 && json['status'] == 'SENT') {
        print("${logHeader("relayNet")} ✅ GameOver envoyé");
        _pendingGameOver = null;
        // Supprimer la sauvegarde pour ce partenaire
        await _clearPendingGameOver(finalState);
        _gameIsOver = true;
      } else {
        throw Exception("Server refused gameover");
      }
    } catch (e) {
      logger.w("⚠️ Réseau indisponible, GameOver mis en attente");
      _pendingGameOver = finalState;
      // Persister
      await _savePendingGameOver(finalState);
      // Ne pas mettre _gameIsOver à true tant que non envoyé
    } finally {
      _sendingGameOver = false;
    }
  }

  @override
  void Function(GameState state)? get onGameStateReceived {
    return GameCallbackManager().onGameStateReceived;
  }

  @override
  set onGameStateReceived(void Function(GameState state)? callback) {
    print(
      "${logHeader("relayNet")} onGameStateReceived setter (hash=${callback?.hashCode})",
    );
    _dispatcher.flush(callback);
  }

  @override
  void Function(GameState state)? get onGameOverReceived {
    return GameCallbackManager().onGameOverReceived;
  }

  @override
  set onGameOverReceived(void Function(GameState state)? callback) {
    print(
      "${logHeader("relayNet")} onGameOverReceived setter (hash=${callback?.hashCode})",
    );
    if (callback != null && _pendingGameOver != null) {
      final pending = _pendingGameOver!;
      _pendingGameOver = null;
      Future.microtask(() => callback(pending));
    }
  }

  Future<void> _handleAndAck({
    required String localName,
    required String partner,
    required String type,
    required int date,
    required Future<void> Function() handler,
  }) async {
    await handler();
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

    // En priorité, envoyer tous les GameOver en attente
    await _resumeAllPendingGameOver();
    // Puis tous les GameState en attente
    await _resumeAllPendingGameStates();

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

              final String stateId = gameState.gameId;
              final now = DateTime.now();

              if (debug) {
                print(
                  "${logHeader("relayNet")} GAMESTATE reçu de $partner (gameId=$stateId) (hash=${gameState.hashCode})",
                );
              }

              await gameStorage.save(gameState, markAsUnread: true);

              await _dispatcher.handleIncoming(gameState, onGameStateReceived);

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

              await gameStorage.save(gameState, markAsUnread: true);

              if (onGameOverReceived != null) {
                onGameOverReceived!(gameState);
              }
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

              if (partner.isNotEmpty) {
                await gameStorage.delete(partner);
              }

              _gameIsOver = false;

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

  @override
  Future<void> disconnect() async {
    try {
      final user = settings.localUser;
      await http.get(Uri.parse('$_relayServerUrl/disconnect?user=$user'));
      if (debug) print('[relayNet] disconnect envoyé pour $user');
    } catch (e) {
      if (debug) print('[relayNet] disconnect erreur: $e');
    }
  }

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
