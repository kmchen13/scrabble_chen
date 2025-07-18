import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../services/utility.dart';
import 'scrabble_net.dart';

class LocalNet implements ScrabbleNet {
  RawDatagramSocket? _udpSocket;
  ServerSocket? _tcpServer;
  Socket? _peerSocket;
  bool _matched = false;
  Timer? _broadcastTimer;
  List<NetworkInterface>? _localInterfaces;
  bool _debug = true;
  bool _udpStopped = false;

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

    if (_debug) print('${logHeader()} TCP server bound to port $localPort');

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
      if (_udpStopped) return;
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket!.receive();
        if (datagram == null) return;

        final udpMsg = utf8.decode(datagram.data);
        if (_debug) print('${logHeader()} Message UDP reçu: $udpMsg');

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

          if (_debug)
            print('${logHeader()} $localName: partenaire détecté $remoteName');

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
              if (_debug)
                print(
                  '${logHeader()} TCP ACK envoyé sur remotePort ${socket.remotePort}: $tcpMsg',
                );

              socket
                  .cast<List<int>>()
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .listen((tcpMsg) {
                    if (_debug) {
                      print('${logHeader()} TCP reçu (après ACK): $tcpMsg');
                      print(
                        "${logHeader()} Callback onGameStateReceived = $onGameStateReceived",
                      );
                    }

                    try {
                      final decoded = jsonDecode(tcpMsg);
                      final gameState = GameState.fromJson(decoded);
                      print(
                        "${logHeader()} onGameStateReceived actuel = ${onGameStateReceived.hashCode}",
                      );

                      onGameStateReceived?.call(gameState);
                      if (_debug)
                        print(
                          '${logHeader()} GameState reçu et décodé (ACK sender).',
                        );
                    } catch (e) {
                      if (_debug)
                        print('${logHeader()} Erreur JSON (ACK sender): $e');
                    }
                  });
            } catch (e) {
              if (_debug) print('${logHeader()} Erreur envoi ACK: $e');
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
      if (_debug)
        print('${logHeader()} UDP CONNECT envoyé: $udpMsg sur port $udpPort');
    });
  }

  void _closeBroadcast() {
    if (_debug) print('${logHeader()} Closing broadcast');
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
          if (_debug) print('${logHeader()} TCP reçu: $tcpMsg');

          if (tcpMsg.trim().startsWith('SCRABBLE_ACK:')) {
            final parts = tcpMsg.split(':');
            if (parts.length < 9) return;
            final leftName = parts[1];
            final leftIP = parts[2];
            final leftPort = int.tryParse(parts[3]) ?? 0;
            final leftStartTime = int.tryParse(parts[4]) ?? 0;
            final rightName = parts[5];
            final rightIP = parts[6];
            final rightPort = int.tryParse(parts[7]) ?? 0;
            final rightStartTime = int.tryParse(parts[8]) ?? 0;

            onMatched?.call(
              leftName: leftName,
              leftIP: leftIP,
              leftPort: leftPort,
              leftStartTime: leftStartTime,
              rightName: rightName,
              rightIP: rightIP,
              rightPort: rightPort,
              rightStartTime: rightStartTime,
            );
          } else {
            try {
              final decoded = jsonDecode(tcpMsg);
              final gameState = GameState.fromJson(decoded);
              onGameStateReceived?.call(gameState);
              if (_debug) print('${logHeader()} GameState reçu et décodé.');
            } catch (e) {
              if (_debug)
                print(
                  '${logHeader()} Message TCP inattendu: $tcpMsg\nErreur: $e',
                );
            }
          }
        });
  }

  @override
  void sendGameState(GameState state, {int attempt = 1}) {
    final jsonString = jsonEncode(state.toJson());

    if (_peerSocket == null) {
      if (_debug) {
        print(
          '${logHeader()} ⚠️ _peerSocket est null (tentative $attempt) — retry dans 300ms...',
        );
      }
      if (attempt < 10) {
        Future.delayed(const Duration(milliseconds: 300), () {
          sendGameState(state, attempt: attempt + 1);
        });
      } else {
        if (_debug) print('${logHeader()} ❌ Abandon après 10 tentatives.');
      }
      return;
    }

    try {
      _peerSocket!.writeln(jsonString);
      _peerSocket!.flush();
      if (_debug) {
        print(
          '${logHeader()} ✅ GameState envoyé sur port TCP ${_peerSocket!.remotePort}',
        );
      }
    } catch (e) {
      if (_debug) {
        print('${logHeader()} ❌ Erreur lors de l\'envoi du GameState: $e');
      }
    }
  }

  void disconnect() {
    _closeBroadcast();
    _tcpServer?.close();
    _peerSocket?.destroy();
    if (_debug) print('${logHeader()} Déconnecté');
  }

  String _findCommonIP(remoteIP) {
    //Recherche du réseau commun
    String remoteNet = remoteIP.split('.').first;
    final address = _localInterfaces!
        .expand((i) => i.addresses)
        .firstWhere(
          (addr) => !addr.isLoopback && addr.address.startsWith(remoteNet),
          orElse: () => throw Exception('Pas de réseau commun'),
        );
    settings.localIP = address.address;
    return address.address;
  }
}
