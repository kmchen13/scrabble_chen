import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/settings_service.dart';
import 'services/game_storage.dart';
import 'models/game_state.dart';
import 'network/scrabble_net.dart';
import 'start_screen.dart';
import 'game_screen.dart';
import 'param_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  runApp(const ScrabbleApp());
}

class ScrabbleApp extends StatelessWidget {
  const ScrabbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GameState? _savedGameState;
  bool _loading = true;
  late ScrabbleNet _net;

  @override
  void initState() {
    super.initState();
    _net = ScrabbleNet();
    _loadSavedGame();
  }

  Future<void> _loadSavedGame() async {
    final savedGame = await loadLastGameState(); // Map<String, dynamic>?
    setState(() {
      if (savedGame != null) {
        _savedGameState = GameState.fromJson(savedGame);
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble_P2P ;-)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StartScreen()),
                  );
                },
                child: const Text("Commencer une partie"),
              ),
              if (_savedGameState != null)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => GameScreen(
                              net: _net,
                              gameState: _savedGameState!,
                              onGameStateUpdated: (updatedState) {
                                _net.sendGameState(updatedState);
                              },
                            ),
                      ),
                    );
                  },
                  child: const Text("Reprendre la dernière partie"),
                ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ParamScreen()),
                  );
                },
                child: const Text("Paramètres"),
              ),
              ElevatedButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: const Text("Quitter"),
              ),
            ] else
              const Text("P2P non disponible sur navigateur"),
          ],
        ),
      ),
    );
  }
}
