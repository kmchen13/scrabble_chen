// host_screen.dart
import 'package:flutter/material.dart';

import 'models/game_state.dart';
import 'services/settings_service.dart';
import 'game_screen.dart';
import 'network/scrabble_server.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  String _log = "En attente d'un joueur...";
  ScrabbleServer? server;

  @override
  void initState() {
    super.initState();
    _startScrabbleServer();
  }

  Future<void> _startScrabbleServer() async {
    server = await ScrabbleServer.create(
      onClientConnected: (String clientUserName) {
        setState(() {
          _log += '\nClient connect\u00e9 : $clientUserName';
        });

        final gameState = GameState.initialize(
          serverUserName: settings.localUserName,
          clientUserName: clientUserName,
        );

        server!.sendToClient(gameState.toJson());

        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  gameState: gameState,
                  client: null,
                  isClient: false,
                ),
          ),
        );
      },
      onError: (Object error) {
        setState(() {
          _log += '\nErreur serveur : $error';
        });
      },
    );
  }

  @override
  void dispose() {
    server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Héberger une partie")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("En attente d'une connexion..."),
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
