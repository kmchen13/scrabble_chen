// waiting_screen.dart
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/models/game_state.dart';

class WaitingScreen extends StatefulWidget {
  final String leftName;
  final GameState? bufferedGameState;
  final ScrabbleNet net;

  const WaitingScreen({
    super.key,
    required this.leftName,
    required this.bufferedGameState,
    required this.net,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  @override
  void initState() {
    super.initState();

    // 🔹 Si un GameState est déjà arrivé avant le montage
    if (widget.bufferedGameState != null) {
      Future.microtask(() => _navigateToGameScreen(widget.bufferedGameState!));
    }

    // 🔹 Écoute future de GameState reçu
    widget.net.onGameStateReceived = (GameState newState) {
      Future.microtask(() => _navigateToGameScreen(newState));
    };
  }

  void _navigateToGameScreen(GameState gameState) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              net: widget.net,
              gameState: gameState,
              onGameStateUpdated: (gs) => widget.net.sendGameState(gs),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(defaultTitle)),
      body: Center(
        child: Text(
          "Partenaire trouvé : ${widget.leftName}\n\n👉 À lui de jouer en premier.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
