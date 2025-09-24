import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'scrabble_net.dart';
import '../constants.dart';

/*
 *  LocalNet is a class that implements the ScrabbleNet interface
 *  for local network play using UDP and TCP.
 *  It handles player matching, game state transmission, and network communication. 
 * Connection starts though UDP broadcast with userName, expectedPartner and startTime.
 * When match occurs it sends an ACK via TCP to the partner.
 * When ACK received 
 */

class LocalNet implements ScrabbleNet {
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Socket? _peerSocket;
  bool _matched = false;
  Timer? _broadcastTimer;
  List<NetworkInterface>? _localInterfaces;
  bool _udpStopped = false;
  int _lastGameStateId = 0;
  final Map<int, Timer> _pendingAcks = {};

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
    //ouverture connexion TCP
    _tcpServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _tcpServer!.listen(_handleIncomingTCP);
    final localPort = _tcpServer!.port;
    settings.localPort = localPort;

    if (debug)
      debugPrint(
        '${logHeader("LocalNet")} TCP server bound to port $localPort',
      );

    //ouverture conneciont UDP
    _udpStopped = false;
    final udpPort = settings.udpPort;
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, udpPort);
    _udpSocket!.broadcastEnabled = true;
    _startBroadcast(localName, '', localPort, udpPort, startTime);

    _localInterfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );

    _udpSocket!.listen((event) async {
      onStatusUpdate?.call('Connection au serveur établie mode local');
      if (_udpStopped) return;
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram == null) return;

        final udpMsg = utf8.decode(datagram.data);
        if (debug)
          debugPrint('${logHeader("LocalNet")} Message UDP reçu: $udpMsg');

        if (udpMsg.startsWith('SCRABBLE_CONNECT:')) {
          final parts = udpMsg.split(':');
          if (parts.length < 5) return;

          final remoteName = parts[1];
          final remoteExpectedName = parts[2];
          final remotePort = int.tryParse(parts[3]) ?? 0;
          final remoteStartTime = int.tryParse(parts[4]) ?? 0;
          final remoteIP = datagram.address.address;

          if (remoteName == localName)
            return; //Les joueurs voient leurs propres broadcasts

          final accepted = ScrabbleNet.match(
            localName,
            expectedName,
            remoteName,
            remoteExpectedName,
          );

          if (debug)
            debugPrint(
              '${logHeader("LocalNet")} $localName: partenaire détecté $remoteName',
            );

          if (accepted && !_matched) {
            _matched = true;
            _udpStopped = true;
            _closeBroadcast();

            String localIP = _findCommonIP(remoteIP);

            // Envoyer ACK via TCP
            wait(500);
            try {
              final socket = await Socket.connect(remoteIP, remotePort);
              _peerSocket = socket;
              String tcpMsg =
                  'SCRABBLE_ACK:$localName:$localIP:$localPort:$startTime:$remoteName:$remoteIP:$remotePort:$remoteStartTime';
              socket.writeln(tcpMsg);
              if (debug)
                debugPrint(
                  '${logHeader("LocalNet")} TCP ACK envoyé sur remotePort ${socket.remotePort}: $tcpMsg',
                );

              socket
                  .cast<List<int>>()
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .listen((tcpMsg) {
                    if (debug) {
                      debugPrint(
                        '${logHeader("LocalNet")} TCP reçu (après ACK): $tcpMsg',
                      );
                    }

                    // On ne crée pas de GameState ici
                    try {
                      final decoded = jsonDecode(tcpMsg);
                      final gameState = GameState.fromJson(decoded);
                      onGameStateReceived?.call(gameState);
                    } catch (_) {
                      if (debug)
                        debugPrint(
                          '${logHeader("LocalNet")} Message non JSON ignoré.',
                        );
                    }
                  });

              // 🔹 Déclenchement pur du match
              onMatched?.call(
                leftName: localName,
                leftIP: localIP,
                leftPort: localPort,
                leftStartTime: startTime,
                rightName: remoteName,
                rightIP: remoteIP,
                rightPort: remotePort,
                rightStartTime: remoteStartTime,
              );
            } catch (e) {
              if (debug)
                debugPrint('${logHeader("LocalNet")} Erreur envoi ACK: $e');
            }
          }
        }
      }
    });
  }

  void _startBroadcast(
    String localName,
    String expectedName,
    int tcpPort,
    int udpPort,
    int startTime,
  ) {
    final random = Random();
    int delay = 700 + random.nextInt(500);
    _broadcastTimer = Timer.periodic(Duration(milliseconds: delay), (timer) {
      final udpMsg =
          'SCRABBLE_CONNECT:$localName:$expectedName:$tcpPort:$startTime';

      _udpSocket!.send(
        utf8.encode(udpMsg),
        InternetAddress('255.255.255.255'),
        udpPort,
      );
      onStatusUpdate?.call('Connection au serveur...');
      if (debug)
        debugPrint(
          '${logHeader("LocalNet")} UDP CONNECT envoyé: $udpMsg sur port $udpPort',
        );
    });
  }

  void _closeBroadcast() {
    if (debug) debugPrint('${logHeader("LocalNet")} Closing broadcast');
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _udpSocket?.close();
    _udpSocket = null;
  }

  void _handleIncomingTCP(Socket socket) {
    if (_peerSocket != null) return;
    _peerSocket = socket;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((tcpMsg) {
          _closeBroadcast();
          if (debug) debugPrint('${logHeader("LocalNet")} TCP reçu: $tcpMsg');

          if (tcpMsg.trim().startsWith('SCRABBLE_ACK:')) {
            // @todo implémenter la possibilité d'envoyer des messages; switch ($startswith)
            final parts = tcpMsg.split(':');
            if (parts.length < 9) return;

            onMatched?.call(
              leftName: parts[1],
              leftIP: parts[2],
              leftPort: int.tryParse(parts[3]) ?? 0,
              leftStartTime: int.tryParse(parts[4]) ?? 0,
              rightName: parts[5],
              rightIP: parts[6],
              rightPort: int.tryParse(parts[7]) ?? 0,
              rightStartTime: int.tryParse(parts[8]) ?? 0,
            );
          } else if (tcpMsg.trim().startsWith('SCRABBLE_QUIT:')) {
            final parts = tcpMsg.split(':');
            if (parts.length < 4) {
              if (debug) print("[localNet] 🛑 Message QUIT mal formé");
              return;
            }
            quit(parts[1], parts[2], parts[3]);
            if (debug) print("[localNet] 🛑 Le partenaire a abandonné");
            gameStorage.clear(parts[3]);
            disconnect();
            onConnectionClosed?.call();
          } else {
            try {
              final decoded = jsonDecode(tcpMsg);
              final gameState = GameState.fromJson(decoded);
              onGameStateReceived?.call(gameState);
            } catch (e) {
              if (debug)
                debugPrint(
                  '${logHeader("LocalNet")} Message TCP inattendu: $tcpMsg\nErreur: $e',
                );
            }
          }
        });
  }

  @override
  void sendGameState(GameState state, {int attempt = 1}) {
    final jsonString = jsonEncode(state.toJson());

    _lastGameStateId++;

    if (_peerSocket == null) {
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ⚠️ _peerSocket est null (tentative $attempt) — retry dans 300ms...',
        );
      }
      if (attempt < 10) {
        Future.delayed(const Duration(milliseconds: 300), () {
          sendGameState(state, attempt: attempt + 1);
        });
      } else {
        if (debug)
          debugPrint('${logHeader("LocalNet")} ❌ Abandon après 10 tentatives.');

        onError?.call(
          'Impossible d\'envoyer le GameState après 10 tentatives.',
        );
      }
      return;
    }

    try {
      _peerSocket!.writeln(jsonString);
      _peerSocket!.flush();
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ✅ GameState envoyé sur port TCP ${_peerSocket!.remotePort}',
        );
      }
    } catch (e) {
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ❌ Erreur lors de l\'envoi du GameState: $e',
        );
      }
    }
  }

  @override
  void sendGameOver(GameState finalState, {int attempt = 1}) {
    final jsonString = jsonEncode({
      "type": "gameOver",
      "message": finalState.toJson(),
    });

    if (_peerSocket == null) {
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ⚠️ _peerSocket est null (tentative $attempt) — retry dans 300ms...',
        );
      }
      if (attempt < 10) {
        Future.delayed(const Duration(milliseconds: 300), () {
          sendGameOver(finalState, attempt: attempt + 1);
        });
      } else {
        if (debug)
          debugPrint('${logHeader("LocalNet")} ❌ Abandon envoi gameOver.');

        onError?.call('Impossible d\'envoyer le gameOver après 10 tentatives.');
      }
      return;
    }

    try {
      _peerSocket!.writeln(jsonString);
      _peerSocket!.flush();
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ✅ gameOver envoyé sur port TCP ${_peerSocket!.remotePort}',
        );
      }
    } catch (e) {
      if (debug) {
        debugPrint(
          '${logHeader("LocalNet")} ❌ Erreur lors de l\'envoi du gameOver: $e',
        );
      }
    }
  }

  @override
  void Function(GameState finalState)? onGameOverReceived;

  void disconnect() {
    _closeBroadcast();
    _tcpServer?.close();
    _peerSocket?.destroy();
    onStatusUpdate?.call('Déconnecté');
    if (debug) debugPrint('${logHeader("LocalNet")} Déconnecté');
  }

  void Function(String error)? onError;

  String _findCommonIP(String remoteIP) {
    // Recherche du réseau commun
    String remoteNet = remoteIP.split('.').first;

    final matching =
        _localInterfaces!
            .expand((i) => i.addresses)
            .where(
              (addr) => !addr.isLoopback && addr.address.startsWith(remoteNet),
            )
            .toList();

    if (matching.isEmpty) {
      onStatusUpdate?.call('Pas de réseau commun');
      return ''; // ou bien throw Exception('Pas de réseau commun');
    }

    final address = matching.first;
    settings.localIP = address.address;
    return address.address;
  }

  @override
  Future<void> quit(userName, partner, gameId) async {
    // Prévenir le partenaire via TCP
    final quitMessage = 'SCRABBLE_QUIT:$userName:$partner:$gameId';
    _peerSocket?.writeln(quitMessage);

    if (debug)
      print("[localNet] 🛑 Partie abandonnée par ${settings.localUserName}");

    // Supprimer l’état de jeu local
    await gameStorage.clear(gameId);

    // Fermer la socket
    disconnect();

    // Notifier l’UI
    onConnectionClosed?.call();
  }

  @override
  void startPolling(String localName) {
    // Rien à faire ici pour LocalNet
  }

  @override
  void Function(String message)? onStatusUpdate;

  @override
  void Function()? onConnectionClosed;

  @override
  void flushPending() {}
}
