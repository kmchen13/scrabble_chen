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
import 'services/game_storage.dart';
import 'models/game_state.dart';
import 'network/scrabble_net.dart';
import 'start_screen.dart';
import 'game_screen.dart';
import 'param_screen.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings();
  await Hive.initFlutter();

  // Enregistrement des adapters générés
  Hive.registerAdapter(GameStateAdapter());

  // Ouverture de la box via ton wrapper
  await gameStorage.init();

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
      _savedGameState = gameStorage.load();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    });
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
                    final saved = _savedGameState!;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) {
                          final gameScreen = GameScreen(
                            net: _net,
                            gameState: saved,
                            onGameStateUpdated: (updatedState) {
                              _net.sendGameState(updatedState);
                            },
                          );

                          // Utiliser WidgetsBinding pour exécuter le code après que le widget soit construit
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            String myName = settings.localUserName;
                            if (saved.isMyTurn(myName)) {
                              // C’est au joueur local de jouer → on injecte l’état sauvegardé
                              _net.onGameStateReceived?.call(saved);
                            } else {
                              // C’est à l’adversaire de jouer → on lance le polling
                              _net.startPolling(myName);
                            }
                          });

                          return gameScreen;
                        },
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
