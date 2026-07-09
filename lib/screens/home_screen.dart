import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/app_log.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import '../constants.dart';
import 'game_screen.dart';
import 'param_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with RouteAware, WidgetsBindingObserver {
  late final ScrabbleNet _net = ScrabbleNet();
  bool _loading = true;
  late ModalRoute? _route;
  List<String> _savedGames = [];
  List<Map<String, dynamic>> _freePlayers = [];
  bool _loadingFreePlayers = false;

  // ✅ Variables pour gérer le matching
  bool _navigated = false;
  GameState? _bufferedGameState;
  String _searchStatus = "";

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
    WidgetsBinding.instance.removeObserver(this);
    if (_route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    _net.onStatusUpdate = null;
    _net.onMatched = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print('[HomeScreen] App resumed, refreshing data...');
      if (!_loading) {
        _refreshData();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _navigated = false;
    _bufferedGameState = null;

    // ✅ Écouter les mises à jour de statut
    _net.onStatusUpdate = (msg) {
      if (mounted) {
        print('[HomeScreen] Status: $msg');
        setState(() {
          _searchStatus = msg;
        });
      }
    };

    // ✅ Écouter le match avec un partenaire
    _net.onMatched = _handleMatched;

    // ✅ Écouter les GameState entrants
    _net.onGameStateReceived = (GameState gameState) {
      if (!mounted) return;

      print(
        '[HomeScreen] GameState reçu de ${gameState.partnerFrom(settings.localUserName)}',
      );

      if (_navigated) {
        _bufferedGameState = gameState;
        return;
      }

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

    // ✅ Écouter la fin de partie (GameOver)
    _net.onGameOverReceived = (GameState gameState) {
      if (!mounted) return;

      print(
        '[HomeScreen] GameOver reçu de ${gameState.partnerFrom(settings.localUserName)}',
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Partie terminée ! ${gameState.partnerFrom(settings.localUserName)} a terminé la partie.",
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );

        final partner = gameState.partnerFrom(settings.localUserName);
        gameStorage.delete(partner).then((_) {
          if (mounted) {
            setState(() {
              _savedGames.remove(partner);
            });
          }
        });
      });
    };

    // ✅ Écouter l'abandon de partie (Quit)
    _net.onGameQuitReceived = (String partner) {
      if (!mounted) return;

      print('[HomeScreen] Quit reçu de $partner');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$partner a abandonné la partie"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );

        gameStorage.delete(partner).then((_) {
          if (mounted) {
            setState(() {
              _savedGames.remove(partner);
            });
          }
        });
      });
    };

    // ⚡ Chargement initial
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeData();
    });
  }

  // 📦 Chargement initial complet
  Future<void> _initializeData() async {
    await gameStorage.init();

    if (settings.localUserName.trim().isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ParamScreen()),
      );
      return;
    }

    try {
      final results = await Future.wait([
        gameStorage.listSavedGames(),
        _net.getFreePlayers(),
      ]);

      final ids = results[0] as List<String>;
      final players = results[1] as List<Map<String, dynamic>>;

      final filtered =
          players
              .where((p) => p['user_name'] != settings.localUserName)
              .toList();

      if (mounted) {
        setState(() {
          _savedGames = ids;
          _freePlayers = filtered;
          _loading = false;
        });
        _net.startPolling(settings.localUserName);
      }
    } catch (e) {
      print('[HomeScreen] Erreur lors du chargement initial: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔄 Rafraîchissement des données
  Future<void> _refreshData() async {
    await _refreshFreePlayers();
    await _refreshSavedGames();
  }

  Future<void> _refreshSavedGames() async {
    try {
      final ids = await gameStorage.listSavedGames();
      if (mounted) {
        setState(() => _savedGames = ids);
      }
    } catch (e) {
      print('[HomeScreen] Erreur refresh parties sauvegardées: $e');
    }
  }

  Future<void> _refreshFreePlayers() async {
    if (_loadingFreePlayers) return;

    setState(() => _loadingFreePlayers = true);
    try {
      final players = await _net.getFreePlayers();
      final filtered =
          players
              .where((p) => p['user_name'] != settings.localUserName)
              .toList();

      if (mounted) {
        setState(() => _freePlayers = filtered);
      }
    } catch (e) {
      print('[HomeScreen] Erreur refresh joueurs libres: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingFreePlayers = false);
      }
    }
  }

  // ✅ Gestion du match
  void _handleMatched({
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

    if (_navigated) return;
    _navigated = true;

    // ✅ Cacher le SnackBar de recherche
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (localName == leftName) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Partie engagée avec $leftName, à lui de jouer"),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
            action: SnackBarAction(
              label: "OK",
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _refreshData();
              },
            ),
          ),
        );
      }
    });
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

  // ✅ Démarrer la recherche d'un adversaire
  void _startSearching(String? targetPlayer) {
    _navigated = false;
    _bufferedGameState = null;

    final startTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expectedName = targetPlayer ?? '';

    _net.connect(
      localName: settings.localUserName,
      expectedName: expectedName,
      startTime: startTime,
    );

    // ✅ Afficher un SnackBar persistant
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                targetPlayer != null
                    ? "Recherche de $targetPlayer..."
                    : "Recherche d'un adversaire...",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(days: 1), // ✅ SnackBar persistant
        backgroundColor: Colors.blue.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        action: SnackBarAction(
          label: "Annuler",
          textColor: Colors.white,
          onPressed: () {
            _net.stopPolling();
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            setState(() {
              _searchStatus = "Recherche annulée";
            });
          },
        ),
      ),
    );
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
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    String myName = settings.localUserName;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2A3A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2A3A),
        title: Text("$appName-v$version ;-) $myName"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingFreePlayers ? null : _refreshData,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!kIsWeb) ...[
              // ✅ Bouton "Commencer une partie" - recherche aléatoire
              ElevatedButton(
                onPressed: () {
                  _startSearching(null); // ✅ Recherche aléatoire
                },
                child: const Text("Commencer une partie"),
              ),

              // ✅ Liste des joueurs libres
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
                                onPressed: () {
                                  final user = player['user_name'];
                                  _startSearching(user); // ✅ Recherche ciblée
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

              // ✅ Liste des parties sauvegardées
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

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (saved.isMyTurn(myName)) {
                                _net.onGameStateReceived?.call(saved);
                              } else {
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
                          _net.sendGameQuit(myName, partner);
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

              const SizedBox(height: 10),

              // ✅ Boutons Paramètres, Quitter, Logs
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
