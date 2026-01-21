// home_screen.dart
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/services/game_storage.dart';

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
    _refreshSavedGames();
  }

  @override
  void dispose() {
    if (_route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  /// Recharge la liste des parties sauvegardées
  Future<void> _refreshSavedGames() async {
    await gameStorage.init();
    final ids = await gameStorage.listSavedGames();
    if (mounted) {
      setState(() => _savedGames = ids);
    }
  }

  /// Si aucune partie en cours, se connecter automatiquement
  Future<void> _ensureConnectedIfIdle() async {
    final ids = await gameStorage.listSavedGames();
    if (ids.isEmpty) {
      _net.connect(
        localName: settings.localUserName,
        expectedName: settings.expectedUserName,
        startTime: DateTime.now().millisecondsSinceEpoch,
      );
      _net.startPolling(settings.localUserName);
    }
  }

  /// Navigation vers une partie existante
  void _openGame(String gameId) async {
    final gs = await gameStorage.load(gameId);
    if (gs == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              net: _net,
              gameState: gs,
              onGameStateUpdated: (updated) => _net.sendGameState(updated),
            ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // ⚡ Gestion du remote quit
    _net.setOnConnectionClosed((partner, reason) async {
      // ─────────────────────────────
      // 1️⃣ Logique métier (TOUJOURS)
      // ─────────────────────────────
      await gameStorage.delete(partner);
      await _refreshSavedGames();
      await _ensureConnectedIfIdle();

      // ─────────────────────────────
      // 2️⃣ Logique UI (SI POSSIBLE)
      // ─────────────────────────────
      if (!mounted) {
        // On ne peut pas afficher d’UI,
        // mais l’état est maintenant cohérent
        return;
      }

      final navigator = Navigator.of(context);
      final bool inGame = navigator.canPop();

      if (inGame) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder:
              (_) => AlertDialog(
                title: const Text("Partie terminée"),
                content: Text("$partner a quitté la partie"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );

        navigator.popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$partner a quitté la partie : $reason")),
        );
      }
    });

    // ⚡ Gestion des parties reçues
    _net.onGameStateReceived = (GameState newState) async {
      await gameStorage.save(newState);
      _refreshSavedGames();
    };

    // ⚡ Gestion du match
    _net.onMatched = ({
      required String leftName,
      required String rightName,
      required int leftStartTime,
      required int rightStartTime,
      required String leftIP,
      required int leftPort,
      required String rightIP,
      required int rightPort,
    }) async {
      final localName = settings.localUserName;

      // Joueur gauche → crée GameState initial et sauvegarde
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
        await gameStorage.save(gameState);
        _refreshSavedGames();
      }
      // Joueur droite → ne fait rien, recevra GameState via onGameStateReceived
    };

    // ⚡ Initialisation gameStorage + polling + connexion
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await gameStorage.init();
        final ids = await gameStorage.listSavedGames();
        if (mounted) {
          setState(() {
            _savedGames = ids;
            _loading = false;
          });
          _net.startPolling(settings.localUserName);

          // Connexion immédiate
          _net.connect(
            localName: settings.localUserName,
            expectedName: settings.expectedUserName,
            startTime: DateTime.now().millisecondsSinceEpoch,
          );
        }
      } catch (e) {
        print('[HomeScreen] Erreur init HomeScreen: $e');
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble P2P")),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _savedGames.isEmpty
              ? const Center(child: Text("Aucune partie en cours"))
              : ListView.builder(
                itemCount: _savedGames.length,
                itemBuilder: (_, i) {
                  final id = _savedGames[i];
                  return ListTile(
                    title: Text(id),
                    onTap: () => _openGame(id),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text("Supprimer la partie"),
                                content: Text(
                                  "Supprimer définitivement la partie \"$id\" ?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text("Annuler"),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text("Supprimer"),
                                  ),
                                ],
                              ),
                        );

                        if (confirmed == true) {
                          await gameStorage.delete(id);
                          await _refreshSavedGames();
                          await _ensureConnectedIfIdle();
                        }
                      },
                    ),
                  );
                },
              ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // TODO: ouvrir paramètres
              },
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                _net.disconnect();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
