// start_screen.dart
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import 'package:scrabble_P2P/screens/waiting_screen.dart';
import 'package:scrabble_P2P/models/game_state.dart';

class StartScreen extends StatefulWidget {
  final ScrabbleNet net;
  const StartScreen({super.key, required this.net});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late ScrabbleNet _net;
  bool _navigated = false;
  GameState? _bufferedGameState;

  @override
  void initState() {
    super.initState();
    _net = widget.net;

    _net.onStatusUpdate = (_) {}; // Peut afficher un log si besoin

    _net.onGameStateReceived = (GameState newState) {
      // Bufferiser si navigation déjà déclenchée
      if (_navigated) {
        _bufferedGameState = newState;
      }
    };

    _net.onMatched = ({
      required String leftName,
      required String rightName,
      required int leftStartTime,
      required int rightStartTime,
      required String leftIP,
      required int leftPort,
      required String rightIP,
      required int rightPort,
    }) {
      if (_navigated) return;
      _navigated = true;

      final localName = settings.localUserName;
      final bool isLeft = leftStartTime > rightStartTime;

      if (localName == leftName) {
        // Joueur gauche → crée GameState et ouvre GameScreen
        final gameState = GameInitializer.createGame(
          isLeft: true,
          leftName: leftName,
          leftIP: leftIP,
          leftPort: leftPort,
          rightName: rightName,
          rightIP: rightIP,
          rightPort: rightPort,
        );
        _navigateToGameScreen(gameState);
      } else {
        // Joueur droite → écran d'attente
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => WaitingScreen(
                  leftName: leftName,
                  bufferedGameState: _bufferedGameState,
                  net: _net,
                ),
          ),
        );
      }
    };

    _net.connect(
      localName: settings.localUserName,
      expectedName: settings.expectedUserName,
      startTime: DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _navigateToGameScreen(GameState gameState) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => GameScreen(
                net: _net,
                gameState: gameState,
                onGameStateUpdated: (gs) => _net.sendGameState(gs),
              ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _net.onStatusUpdate = null;
    _net.onMatched = null;
    _net.disconnect(); // Stop recherche de joueur
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(defaultTitle)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
