import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'game_screen.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/services/utility.dart';
import '../constants.dart';

class StartScreen extends StatefulWidget {
  final ScrabbleNet net;
  const StartScreen({super.key, required this.net});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
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

    _net.onGameStateReceived = (newState) {
      if (debug)
        print(
          '${logHeader("StartScreen")} onGameStateReceived déclenché net identity: ${identityHashCode(_net)} (runtimeType=${_net.runtimeType})',
        );

      if (!mounted || _navigated) return;

      setState(() => _navigated = true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GameScreen(net: _net, gameState: newState),
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
      final bool isLeft = leftStartTime > rightStartTime;

      if (isLeft && settings.localUserName == leftName) {
        final initialGameState = GameInitializer.createGame(
          isLeft: isLeft,
          leftName: leftName,
          leftIP: leftIP,
          leftPort: leftPort,
          rightName: rightName,
          rightIP: rightIP,
          rightPort: rightPort,
        );
        if (!mounted) return;
        setState(() => _navigated = true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => GameScreen(net: _net, gameState: initialGameState),
            ),
          );
        });
      } else if (mounted) {
        setState(() {
          _log = 'Partenaire trouvé. A lui de jouer';
        });
      }
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
    _net.onGameStateReceived = null;
    _net.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connexion en cours")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            _log,
            style: const TextStyle(fontFamily: 'monospace'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
