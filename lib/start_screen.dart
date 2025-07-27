import 'package:flutter/material.dart';
import 'network/scrabble_net.dart';
import 'models/game_state.dart';
import 'services/settings_service.dart';
import 'game_screen.dart';
import 'services/game_initializer.dart';
import 'services/utility.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  String _log = "Recherche d'un joueur...";
  bool _debug = true;
  bool _connected = false;
  bool _gameStateSent = false;
  bool _navigated = false;
  late ScrabbleNet _net;
  final int _startTimestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _net = ScrabbleNet();
    if (_debug)
      print('${logHeader('startScreen')} _net hashCode = ${_net.hashCode}');

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
      print("[startScreen] onGameStateReceived déclenché !");
      if (!mounted || _navigated) return;

      setState(() => _navigated = true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) => GameScreen(
                  net: _net,
                  gameState: newState,
                  onGameStateUpdated: (updatedState) {
                    _net.sendGameState(updatedState);
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
      final isLeft = leftStartTime < rightStartTime;

      final initialGameState = GameInitializer.createGame(
        isLeft: isLeft,
        leftName: leftName,
        leftIP: leftIP,
        leftPort: leftPort.toString(),
        rightName: rightName,
        rightIP: rightIP,
        rightPort: rightPort.toString(),
      );

      if (isLeft) {
        _net.sendGameState(initialGameState);
      }

      if (!_navigated) {
        setState(() => _navigated = true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => GameScreen(
                    net: _net,
                    gameState: initialGameState,
                    onGameStateUpdated: (updatedState) {
                      _net.sendGameState(updatedState);
                    },
                  ),
            ),
          );
        });
      }
    };
  }

  @override
  void dispose() {
    if (_debug) {
      print('${logHeader('startScreen')} dispose() appelé');
      // debugPrintStack(label: 'Stack au moment de dispose():');
    }
    _net.onMatched = null;
    //    _net.onGameStateReceived = null;
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
