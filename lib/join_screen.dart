// join_screen.dart
import 'package:flutter/material.dart';

import 'models/game_state.dart';
import 'services/settings_service.dart';
import 'game_screen.dart';
import 'network/scrabble_client.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  String _log = "Connexion en cours...";
  ScrabbleClient? client;
  String serverUserName = 'Hôte';

  @override
  void initState() {
    super.initState();
    _connectToScrabbleServer();
  }

  Future<void> _connectToScrabbleServer() async {
    final localUserName = settings.localUserName;

    client = await ScrabbleClient.create(
      localUserName: localUserName,
      onDiscovered: (String ip, int port, String discoveredUserName) async {
        serverUserName = discoveredUserName;
        setState(() {
          _log += '\nHôte détecté : $ip:$port ($serverUserName)';
        });
        await _connectToHost(ip, port);
      },
    );

    client!.onMessageReceived = (message) {
      setState(() {
        _log += '\n[Serveur] $message';
      });

      try {
        final gameState = GameState.fromJson(message);

        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  gameState: gameState,
                  client: client!,
                  isClient: true,
                ),
          ),
        );
      } catch (e) {
        setState(() {
          _log += '\nErreur de décodage GameState: $e';
        });
      }
    };

    client!.onConnectionClosed = () {
      setState(() {
        _log += '\nConnexion fermée.';
      });
    };
  }

  Future<void> _connectToHost(String ip, int port) async {
    try {
      await client!.connect(ip, port);
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
