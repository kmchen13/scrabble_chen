import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import '../constants.dart';
import 'start_screen.dart';
import 'game_screen.dart';
import 'param_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final ScrabbleNet _net = ScrabbleNet();
  bool _loading = true;
  late ModalRoute? _route;
  List<String> _savedGames = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_route is PageRoute) {
      routeObserver.subscribe(this, _route as PageRoute);
    }
  }

  @override
  void dispose() {
    if (_route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  Map<String, dynamic> _convertMap(Map<dynamic, dynamic> input) {
    return input.map((key, value) {
      final String stringKey = key.toString();
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
  void initState() {
    super.initState();

    // ⚡ Différer l'appel à load() pour s'assurer que gameStorage.init() est terminé
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await gameStorage.init(); // s'assure que Hive est ouvert
      try {
        final ids = await gameStorage.listSavedGames();
        if (mounted) {
          setState(() {
            if (ids.isEmpty) {
              _savedGames = [];
            } else {
              _savedGames = ids;
            }
            _loading = false;
          });
        }
      } catch (e) {
        print('[HomeScreen] Erreur lors du chargement des GameStates: $e');
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String myName = settings.localUserName;

    return Scaffold(
      appBar: AppBar(title: Text("$appName-v$version ;-) $myName")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StartScreen(net: _net)),
                  );
                },
                child: const Text("Commencer une partie"),
              ),
              if (_savedGames.isNotEmpty) ...[
                const Text("Reprendre une partie :"),
                for (final id in _savedGames)
                  FutureBuilder<GameState?>(
                    future: gameStorage.load(id),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }
                      final saved = snapshot.data!;

                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) {
                                      final gameScreen = GameScreen(
                                        net: _net,
                                        gameState: saved,
                                        onGameStateUpdated: (saved) {
                                          _net.sendGameState(saved);
                                        },
                                      );
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (saved.isMyTurn(myName)) {
                                              _net.onGameStateReceived?.call(
                                                saved,
                                              );
                                            } else {
                                              _net.startPolling(myName);
                                            }
                                          });
                                      return gameScreen;
                                    },
                                  ),
                                );
                              },
                              child: Text("Partie avec $id"),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              // suppression Hive
                              await gameStorage.delete(id);

                              // envoi /quit au serveur
                              _net.quit(myName, id);

                              // rafraîchit la liste locale
                              setState(() {
                                _savedGames.remove(id);
                              });
                            },
                          ),
                        ],
                      );
                    },
                  ),
              ],

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
