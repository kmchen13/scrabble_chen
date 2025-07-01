// relay_P2P/host_screen.dart (extrait simplifié)

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/game_state.dart';
import '../game_screen.dart';
import '../services/game_initializer.dart';
import '../services/settings_service.dart';

class RelayHostScreen extends StatefulWidget {
  const RelayHostScreen({super.key});

  @override
  State<RelayHostScreen> createState() => _RelayHostScreenState();
}

class _RelayHostScreenState extends State<RelayHostScreen> {
  late WebSocketChannel _channel;
  String _log = '';
  String? _remotePlayerName;

  @override
  void initState() {
    super.initState();
    _connectToRelayServer();
  }

  void _connectToRelayServer() {
    // Remplace par ton URL serveur WebSocket
    _channel = WebSocketChannel.connect(Uri.parse('wss://ton-serveur-relay'));

    _channel.stream.listen(
      (message) {
        setState(() {
          _log += '\n[Serveur] $message';
        });

        if (message.startsWith('JOIN:')) {
          _remotePlayerName = message.substring(5);

          // Envoie une confirmation au client
          _channel.sink.add('WELCOME');

          // Crée les états de jeu pour host et client
          final result = GameInitializer.createGame();
          final hostGameState = result.hostGameState;
          final clientGameState = result.clientGameState;

          // Envoie les lettres initiales du client
          _channel.sink.add(
            'LETTERS:${clientGameState.playerLetters.join(",")}',
          );

          // Lance le jeu côté host avec son état
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => GameScreen(
                    gameState: hostGameState,
                    localUserName: settings.localUserName,
                    remoteUserName: _remotePlayerName!,
                    // Ne pas passer le _channel dans GameScreen (logique métier séparée)
                  ),
            ),
          );

          // Ici, côté client, il faudra écouter le message 'LETTERS:' pour récupérer ses lettres, créer son GameState, puis lancer son GameScreen
        }
      },
      onError: (err) {
        setState(() {
          _log += '\nErreur: $err';
        });
      },
    );
  }

  void _handleMovePlayed(GameMove move) {
    // Encode le coup joué en message texte
    final msg = 'MOVE:${move.letter},${move.row},${move.col}';
    _channel.sink.add(msg);

    setState(() {
      _log += '\n[Move envoyé] $msg';
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hôte Relay')),
      body: Padding(padding: const EdgeInsets.all(16), child: Text(_log)),
    );
  }
}
