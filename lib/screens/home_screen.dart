import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/app_log.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:share_plus/share_plus.dart';
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
  List<Map<String, dynamic>> _freePlayers = [];
  bool _loadingFreePlayers = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    if (_route is PageRoute) {
      routeObserver.subscribe(this, _route as PageRoute);
    }
    _refreshSavedGames();
  }

  Future<void> _refreshSavedGames() async {
    await gameStorage.init();
    final ids = await gameStorage.listSavedGames();
    if (mounted) {
      setState(() => _savedGames = ids);
    }
  }

  @override
  void dispose() {
    if (_route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    // ✅ NE PAS déréférencer onGameStateReceived ici
    // car il peut être utilisé par d'autres composants
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

    // ✅ AJOUT : Écouter les GameState entrants sur l'écran d'accueil
    _net.onGameStateReceived = (GameState gameState) {
      if (!mounted) return;

      print(
        '[HomeScreen] GameState reçu de ${gameState.partnerFrom(settings.localUserName)}',
      );

      // ✅ Naviguer directement vers GameScreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        Navigator.push(
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
    };

    _net.setOnConnectionClosed((partner, reason) {
      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Text("$partner a quitté la partie"),
                content: Text(reason),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text("OK"),
                  ),
                ],
              ),
        );

        Navigator.of(context).popUntil((r) => r.isFirst);
      });
    });

    // ⚡ Différer l'appel à load()
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await gameStorage.init();

      // 🔒 Pas de pseudo = pas d'accès au jeu
      if (settings.localUserName.trim().isEmpty) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParamScreen()),
        );
        return;
      }

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
          // ⚡ Démarrage systématique du polling
          _net.startPolling(settings.localUserName);
        }
      } catch (e) {
        print('[HomeScreen] Erreur lors du chargement des GameStates: $e');
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  /// Méthode pour charger les joueurs libres
  Future<void> _loadFreePlayers() async {
    if (_loadingFreePlayers) return;

    setState(() => _loadingFreePlayers = true);
    try {
      final players = await _net.getFreePlayers();
      // Filtrer pour ne pas afficher soi-même
      final filtered =
          players
              .where((p) => p['user_name'] != settings.localUserName)
              .toList();

      if (mounted) {
        setState(() => _freePlayers = filtered);
      }
    } catch (e) {
      print('[HomeScreen] Erreur chargement joueurs libres: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingFreePlayers = false);
      }
    }
  }

  /// Méthode pour rafraîchir la liste des joueurs libres
  Future<void> _refreshFreePlayers() async {
    await _loadFreePlayers();
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
                  // ✅ Quand on va sur StartScreen, on garde le callback
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => StartScreen(net: _net)),
                  );
                },
                child: const Text("Commencer une partie"),
              ),
              if (_savedGames.isNotEmpty) ...[
                const Text("Reprendre une partie :"),
                for (final partner in _savedGames)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final saved = await gameStorage.load(partner);
                            if (saved == null) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => GameScreen(
                                      net: _net,
                                      gameState: saved,
                                      onGameStateUpdated: (saved) {
                                        _net.sendGameState(saved);
                                      },
                                    ),
                              ),
                            );

                            // ✅ Gestion du tour après le push
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (saved.isMyTurn(myName)) {
                                // Si c'est mon tour, je peux jouer
                                _net.onGameStateReceived?.call(saved);
                              } else {
                                // Si c'est le tour de l'adversaire, je poll
                                _net.startPolling(myName);
                              }
                            });
                          },
                          child: Text("Partie avec $partner"),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await gameStorage.delete(partner);
                          _net.quit(myName, partner);
                          setState(() {
                            _savedGames.remove(partner);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () async {
                          final saved = await gameStorage.load(partner);
                          if (saved != null) {
                            _net.sendGameState(saved);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Partie renvoyée au partenaire !",
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
              ],

              // Liste des Joueurs libres
              if (_freePlayers.isNotEmpty) ...[
                const Divider(height: 20),
                const Text(
                  "Joueurs en attente :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_loadingFreePlayers)
                  const CircularProgressIndicator()
                else
                  ..._freePlayers
                      .map(
                        (player) => Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  // ✅ Rejoindre le joueur libre
                                  final user = player['user_name'];
                                  final message = player['message'] ?? '';

                                  // ⚠️ Utiliser la bonne signature de connect
                                  final startTime =
                                      DateTime.now().millisecondsSinceEpoch ~/
                                      1000;

                                  // Afficher un message d'attente
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Demande envoyée à $user... En attente de validation",
                                      ),
                                    ),
                                  );

                                  _net.connect(
                                    localName: settings.localUserName,
                                    expectedName: user,
                                    startTime: startTime,
                                  );
                                },
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(player['user_name']),
                                    if (player['message'] != null &&
                                        player['message'] != '')
                                      Text(
                                        player['message'],
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.info_outline),
                              onPressed: () {
                                // Afficher les infos du joueur
                                showDialog(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title: Text(player['user_name']),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text("Message:"),
                                            Text(
                                              player['message'] ??
                                                  'Aucun message',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              "En attente depuis: ${DateTime.fromMillisecondsSinceEpoch(player['date']).toLocal()}",
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: const Text("OK"),
                                          ),
                                        ],
                                      ),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                      .toList(),
                const Divider(height: 20),
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
                onPressed: () async {
                  await _net.disconnect();
                  SystemNavigator.pop();
                },
                child: const Text("Quitter"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text("Partager les logs"),
                onPressed: () async {
                  final file = await AppLog().getFile();
                  if (file != null && await file.exists()) {
                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'Logs Scrabble P2P');
                  }
                },
              ),
            ] else
              const Text("P2P non disponible sur navigateur"),
          ],
        ),
      ),
    );
  }
}
