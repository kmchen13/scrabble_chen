// relay_P2P/relay_join_screen.dart
import 'package:flutter/material.dart';

import '../network/relay_client.dart';
import '../models/game_state.dart';
import '../services/settings_service.dart';
import '../game_screen.dart';

class RelayJoinScreen extends StatefulWidget {
  const RelayJoinScreen({super.key});

  @override
  State<RelayJoinScreen> createState() => _RelayJoinScreenState();
}

class _RelayJoinScreenState extends State<RelayJoinScreen> {
  final RelayScrabbleClient _client = RelayScrabbleClient();
  String _log = 'Connexion en cours...';
  String? _remoteUserName;

  @override
  void initState() {
    super.initState();

    _client.onMessageReceived = _handleMessage;
    _client.onConnectionClosed = _handleDisconnect;

    _connectToRelay();
  }

  Future<void> _connectToRelay() async {
    final localName = settings.localUserName;
    try {
      await _client.connect(
        'wss://your-relay-server.com/ws',
        0,
      ); // adresse à adapter
      _client.sendMessage('JOIN:$localName');
      setState(() {
        _log = 'Connexion établie, en attente de réponse...';
      });
    } catch (e) {
      setState(() {
        _log = 'Erreur de connexion : $e';
      });
    }
  }

  void _handleMessage(String message) {
    setState(() {
      _log += '\n[Serveur] $message';
    });

    if (message.startsWith('LETTERS:')) {
      final letters = message.substring('LETTERS:'.length).split(',');

      final state = GameState(
        board: GameState.createEmptyBoard(15),
        playerLetters: letters,
        bag: null,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => GameScreen(
                gameState: state,
                localUserName: settings.localUserName,
                remoteUserName: _remoteUserName ?? 'hôte inconnu',
              ),
        ),
      );
    } else if (message.startsWith('WELCOME:')) {
      _remoteUserName = message.substring('WELCOME:'.length);
    }
  }

  void _handleDisconnect() {
    setState(() {
      _log += '\nConnexion terminée.';
    });
  }

  @override
  void dispose() {
    _client.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion en ligne')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            _log,
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
          ),
        ),
      ),
    );
  }
}
