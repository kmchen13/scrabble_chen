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
  String statusMessage = "Connexion en cours…";

  @override
  void initState() {
    super.initState();
    _net = widget.net;

    _net.onStatusUpdate = (msg) {
      setState(() => statusMessage = msg);
    };

    _net.onGameStateReceived = (GameState newState) {
      if (!mounted) return;
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
      final localName = settings.localUserName;

      print(
        "DEBUG onMatched triggered: local=$localName, left=$leftName, right=$rightName, _navigated=$_navigated",
      );

      if (_navigated)
        return; // maintenant le print montre si on est déjà navigué
      _navigated = true;

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
        if (localName == gameState.leftName)
          _net.stopPolling(); // ⬅️ ARRÊTE LE POLLING pour le joueur qui commence
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
    // _net.disconnect(); // Stop recherche de joueur
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),

            Text(
              statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 30),

            // 🔥 Bouton Annuler visible en état "waiting"
            ElevatedButton(
              onPressed: () {
                widget.net.stopPolling(); // ⬅️ ARRÊTE LE POLLING
                Navigator.pop(context); // ⬅️ Retour HomeScreen
              },
              child: const Text("Retour Accueil"),
            ),
          ],
        ),
      ),
    );
  }
}
