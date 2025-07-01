import 'package:flutter/material.dart';

import 'services/settings_service.dart';
import 'services/game_initializer.dart';

import 'game_screen.dart';
import 'network/scrabble_server.dart';
import 'network/local_server.dart';
import 'network/relay_server.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({super.key});

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late final ScrabbleServer server;
  String _log = "Initialisation...\n";

  @override
  void initState() {
    super.initState();

    // Création dynamique du serveur selon communicationMode
    server =
        (settings.communicationMode == 'web')
            ? RelayScrabbleServer()
            : LocalScrabbleServer();

    _startServer();
  }

  void _startServer() {
    final localUserName =
        settings.localUserName.isNotEmpty ? settings.localUserName : 'inconnu';

    server.start(
      onClientConnected: (remoteUserName) {
        setState(() {
          _log += '\nClient connecté : $remoteUserName';
        });

        // Initialise la partie avec tirage des lettres
        final result = GameInitializer.createGame(); // taille 15 par défaut
        final gameState = result.hostGameState;
        final lettersClient = result.clientGameState.playerLetters;

        // Envoi des lettres au client via le serveur
        server.sendToClient('LETTERS:${lettersClient.join(",")}');

        if (!context.mounted) return;

        // Lancer l'écran du jeu avec les états côté serveur
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  gameState: gameState,
                  localUserName: localUserName,
                  remoteUserName: remoteUserName,
                ),
          ),
        );
      },
      onError: (err) {
        setState(() {
          _log += '\nErreur : $err';
        });
      },
    );
  }

  @override
  void dispose() {
    server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hébergeur")),
      body: Padding(padding: const EdgeInsets.all(16), child: Text(_log)),
    );
  }
}
