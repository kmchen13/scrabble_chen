// waiting_screen.dart

import 'package:flutter/material.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/screens/game_screen.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/models/game_state.dart';

class WaitingScreen extends StatefulWidget {
  final String leftName;
  final GameState? bufferedGameState;
  final ScrabbleNet net;

  const WaitingScreen({
    super.key,
    required this.leftName,
    required this.bufferedGameState,
    required this.net,
  });

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen> {
  bool _isWaiting = true;
  String? _quitMessage;

  @override
  void initState() {
    super.initState();

    // 🔹 Si un GameState est déjà arrivé avant le montage
    if (widget.bufferedGameState != null) {
      Future.microtask(() => _navigateToGameScreen(widget.bufferedGameState!));
    }

    // 🔹 Écoute future de GameState reçu
    widget.net.onGameStateReceived = (GameState newState) {
      if (!mounted) return;
      Future.microtask(() => _navigateToGameScreen(newState));
    };

    // ✅ Gérer la déconnexion du partenaire
    widget.net.onGameQuit = (partner) {
      if (!mounted) return;

      setState(() {
        _isWaiting = false;
        _quitMessage = '$partner a quitté la partie';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$partner a quitté la partie'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    };
  }

  @override
  void dispose() {
    widget.net.onGameStateReceived = null;
    widget.net.onGameQuit = null;
    super.dispose();
  }

  void _navigateToGameScreen(GameState gameState) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (_) => GameScreen(
              net: widget.net,
              gameState: gameState,
              onGameStateUpdated: (gs) => widget.net.sendGameState(gs),
            ),
      ),
    );
  }

  void _goToHomeScreen() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Annule et quitte la partie (avec notification au serveur)
  void _cancelAndQuit() async {
    final partner = widget.leftName;
    final me = settings.localUserName;

    try {
      await widget.net.quit(me, partner);
    } catch (e) {
      print('Erreur lors du quit: $e');
    }

    if (mounted) {
      _goToHomeScreen();
    }
  }

  /// Retourne à l'accueil sans attendre (sans notification)
  void _goHomeWithoutWaiting() {
    _goToHomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(defaultTitle),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isWaiting) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 32),
                Text(
                  "Partenaire trouvé : ${widget.leftName}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  "A lui de jouer...",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),

                // ✅ Les deux options affichées de la même manière
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Option 1: Annuler et quitter
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _cancelAndQuit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cancel, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Annuler et quitter',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Option 2: Retour à l'accueil
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _goHomeWithoutWaiting,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Retour à l\'accueil',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_quitMessage != null) ...[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const SizedBox(height: 24),
                Text(
                  _quitMessage!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Que voulez-vous faire ?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // ✅ Les deux options affichées de la même manière
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Option 1: Retourner à l'accueil
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _goToHomeScreen,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.home, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Retour à l\'accueil',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Option 2: Attendre un nouveau partenaire
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isWaiting = true;
                            _quitMessage = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'En attente d\'un nouveau partenaire...',
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 28),
                            SizedBox(height: 4),
                            Text(
                              'Attendre un partenaire',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
