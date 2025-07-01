// join_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

import 'models/game_state.dart';
import 'services/settings_service.dart';
import 'game_screen.dart';
import 'network/scrabble_client.dart';
import 'network/local_client.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  String _log = "Recherche d'un hôte...";
  ScrabbleClient? client;
  String? _detectedHostIp;
  String _remoteUserName = 'Adversaire';

  @override
  void initState() {
    super.initState();
    _listenForBroadcast();
  }

  void _listenForBroadcast() async {
    final RawDatagramSocket udpSocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      42100,
    );

    udpSocket.listen((RawSocketEvent event) async {
      if (event == RawSocketEvent.read) {
        final datagram = udpSocket.receive();
        if (datagram == null) return;

        final message = utf8.decode(datagram.data);
        if (message.startsWith('SCRABBLE_HOST:')) {
          final parts = message.split(':');
          if (parts.length >= 2) {
            final ip = parts[1];
            _detectedHostIp = ip;
            _log += '\nHôte détecté : $ip';

            udpSocket.close();
            await _connectToHost(ip);
          }
        }
      }
    });
  }

  Future<void> _connectToHost(String ip) async {
    final int port = 4567;
    final String localUserName = settings.localUserName;

    client = LocalScrabbleClient();

    client!.onMessageReceived = (message) {
      setState(() {
        _log += '\n[Serveur] $message';
      });

      if (message.startsWith('LETTERS:')) {
        final letters =
            message
                .substring('LETTERS:'.length)
                .split(',')
                .map((s) => s.trim())
                .toList();

        final gameState = GameState(
          playerLetters: letters,
          board: GameState.createEmptyBoard(15),
          bag: null,
        );

        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  gameState: gameState,
                  localUserName: localUserName,
                  remoteUserName: _remoteUserName,
                ),
          ),
        );
      }
    };

    client!.onConnectionClosed = () {
      setState(() {
        _log += '\nConnexion fermée.';
      });
    };

    try {
      await client!.connect(ip, port);
      client!.sendMessage('USERNAME:$localUserName');
      setState(() {
        _log += '\nConnecté à $ip:$port';
      });
    } catch (e) {
      setState(() {
        _log += '\nErreur de connexion : $e';
      });
    }
  }

  @override
  void dispose() {
    client?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rejoindre une partie")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Connexion automatique..."),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _log,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
