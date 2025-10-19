import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/constants.dart';

class StartScreen extends StatefulWidget {
  final ScrabbleNet net;
  const StartScreen({super.key, required this.net});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String _appBarTitle = defaultTitle;
  String _log = "Recherche d'un joueur...";
  bool _navigated = false;
  late ScrabbleNet _net;
  final int _startTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _net = widget.net;
    if (mounted) {
      _net.onStatusUpdate = (msg) {
        setState(() {
          _log = msg;
        });
      };
    }
    if (debug) {
      print('${logHeader('startScreen')} _net hashCode = ${_net.hashCode}');
    }

    // Lancement d'une demande de partenaire.
    // Si 2 joueurs donnent rightName = '' ils sont connectés
    // Sinon il faut que left et right correspondent
    // Le premier qui aura lancé la demande jouera en premier
    _net.connect(
      localName: settings.localUserName,
      expectedName: settings.expectedUserName,
      startTime: _startTimestamp,
    );

    _net.onGameStateReceived = (newState) async {
      if (debug)
        print(
          '${logHeader("StartScreen")} onGameStateReceived déclenché net identity: ${identityHashCode(_net)} (runtimeType=${_net.runtimeType})',
        );

      if (!mounted || _navigated) return;

      // ✅ Sauvegarde immédiate du GameState reçu
      try {
        await gameStorage.save(newState);
        if (debug) {
          print('${logHeader("StartScreen")} GameState initial sauvegardé');
        }
      } catch (e) {
        print(
          '${logHeader("StartScreen")} Erreur lors de la sauvegarde du GameState: $e',
        );
      }

      setState(() => _navigated = true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  net: _net,
                  gameState: newState,
                  onGameStateUpdated: (newState) {
                    _net.sendGameState(newState);
                  },
                ),
          ),
        );
      });
    };

    _net.onMatched = ({
      required String leftName,
      required String leftIP,
      required int leftPort,
      required int leftStartTime,
      required String rightName,
      required String rightIP,
      required int rightPort,
      required int rightStartTime,
    }) {
      // Le premier à envoyer une demande (+ petit startTime) de partenaire est toujours à droite
      // Celui qui rejoint (plus grand StartTime) est toujours à gauche. Il joue le premier coup et envoit le gameState
      // Celui qui est à droite jouera le dernier coup.
      final bool isLeft = leftStartTime > rightStartTime;

      final initialGameState = GameInitializer.createGame(
        isLeft: isLeft,
        leftName: leftName,
        leftIP: leftIP,
        leftPort: leftPort,
        rightName: rightName,
        rightIP: rightIP,
        rightPort: rightPort,
      );
      if (!mounted || _navigated) return;

      if (debug) {
        print('[StartScreen] Navigation vers GameScreen lancée pour $leftName');
        print(
          '[StartScreen][MATCH] left=$leftName ($leftStartTime), right=$rightName ($rightStartTime), isLeft=$isLeft',
        );
        print('[StartScreen][MATCH] localUser=${settings.localUserName}');
      }
      setState(() => _navigated = true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => GameScreen(
                net: _net,
                gameState: initialGameState,
                onGameStateUpdated: (initialGameState) {
                  bool _isFirstSent =
                      initialGameState.rightScore +
                          initialGameState.leftScore ==
                      0;
                  if (_isFirstSent) {
                    if (isLeft && settings.localUserName == leftName) {
                      _net.sendGameState(initialGameState);
                    }
                    _isFirstSent = false;
                  } else {
                    _net.sendGameState(initialGameState);
                  }
                },
              ),
        ),
      );
    };
  }

  @override
  void dispose() {
    if (debug) {
      debugPrint('${logHeader('startScreen')} dispose() appelé');
      // debugPrintStack(label: 'Stack au moment de dispose():');
    }
    _net.onStatusUpdate = null;
    _net.onMatched = null;

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔹 Cercle de chargement animé
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              // 🔹 Texte dynamique de statut
              Text(
                _log,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
