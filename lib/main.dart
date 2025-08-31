/*
* scrabble P2P - A Scrabble game using peer to peer connections
* Copyright (C) 2024  KMC
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Version 1.1.0 - Aout 2024
* mode web / Polling OK. Une seule partie à la fois. Reprise incomplète.
* Version 1.0.2 - Jul 2024
* mode local OK, Jeu OK sans validation des coups

*/
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/settings_service.dart';
import 'models/game_state.dart';
import 'network/scrabble_net.dart';
import 'start_screen.dart';
import 'game_screen.dart';
import 'param_screen.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();

  // Initialiser Hive avant de lancer l'application
  await Hive.initFlutter();
  Hive.registerAdapter(GameStateAdapter());

  // Ouvrir la box ici pour éviter de le faire dans initState
  await Hive.openBox('gameBox');
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
    // Ne chargez pas les données ici, attendez le premier rendu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedGame();
    });
  }

  Future<void> _loadSavedGame() async {
    setState(() => _loading = true);
    try {
      final box = Hive.box('gameBox');
      final data = box.get('currentGame');
      print("Données chargées depuis Hive : $data");

      if (data != null && data is Map) {
        final convertedData = _convertMap(data);
        _savedGameState = GameState.fromMap(convertedData);
        print("GameState désérialisé : $_savedGameState");
      } else {
        print("Aucune donnée valide trouvée dans Hive.");
      }
    } catch (e) {
      print("Erreur lors du chargement du jeu : $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> input) {
    return input.map((key, value) {
      // Convertir la clé en String
      final String stringKey = key.toString();
      // Convertir la valeur récursivement si c'est un Map ou une List
      if (value is Map) {
        return MapEntry(stringKey, _convertMap(value));
      } else if (value is List) {
        return MapEntry(
          stringKey,
          value.map((e) => e is Map ? _convertMap(e) : e).toList(),
        );
      } else {
        return MapEntry(stringKey, value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("$appName-v$version ;-)")),
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
