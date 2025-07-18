import 'package:flutter/material.dart';
import 'models/board.dart';
import 'models/game_state.dart';
import 'models/player_rack.dart';
import 'models/bag.dart';
import 'network/scrabble_net.dart';
import 'services/settings_service.dart';
import 'services/utility.dart';

typedef MovePlayedCallback = void Function(GameMove move);

/// Structure représentant un coup joué.
class GameMove {
  final String letter;
  final int row;
  final int col;

  GameMove({required this.letter, required this.row, required this.col});
}

class GameScreen extends StatefulWidget {
  final ScrabbleNet net;
  final GameState gameState;
  final MovePlayedCallback? onMovePlayed;
  final void Function(GameState updatedGameState)? onGameStateUpdated;

  const GameScreen({
    super.key,
    required this.net,
    required this.gameState,
    this.onMovePlayed,
    this.onGameStateUpdated,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ScrabbleNet _net;
  late List<String> _playerLetters;
  late List<List<String>> _board;
  late List<String> _initialRack;
  final List<({int row, int col, String letter})> _lettersPlacedThisTurn = [];
  String? _selectedLetter; // Lettre temporaire à replacer
  final TransformationController _boardController = TransformationController();

  @override
  void initState() {
    super.initState();

    // Récupération du réseau
    _net = widget.net;

    // Écoute des GameState reçus (mise à jour en temps réel)
    _net.onGameStateReceived = (newState) {
      if (!mounted) return;

      setState(() {
        // Mettre à jour le GameState local avec celui reçu
        widget.gameState.copyFrom(newState);

        // Mettre à jour la vue
        _board =
            widget.gameState.board
                .map((row) => List<String>.from(row))
                .toList();
        _playerLetters =
            widget.gameState.isLeft
                ? widget.gameState.leftLetters
                : widget.gameState.rightLetters;

        _initialRack = List.from(_playerLetters);
        _lettersPlacedThisTurn.clear();
      });
    };
    // Init local du plateau et des lettres
    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();
    _playerLetters =
        widget.gameState.isLeft
            ? widget.gameState.leftLetters
            : widget.gameState.rightLetters;
    _initialRack = List.from(_playerLetters);

    saveSettings();
  }

  List<List<String>> cloneBoard(List<List<String>> board) {
    return board.map((row) => List<String>.from(row)).toList();
  }

  void applyBoardChanges({
    required GameState gameState,
    required List<List<String>> lettersPlacedThisTurn,
  }) {
    for (int row = 0; row < lettersPlacedThisTurn.length; row++) {
      for (int col = 0; col < lettersPlacedThisTurn[row].length; col++) {
        final letter = lettersPlacedThisTurn[row][col];
        if (letter.isNotEmpty) {
          gameState.board[row][col] = letter;
        }
      }
    }
  }

  void _handleLetterPlaced(String letter, int row, int col) {
    if (mounted) {
      setState(() {
        _board[row][col] = letter;
        final index = _playerLetters.indexOf(letter);
        if (index != -1) {
          _playerLetters.removeAt(index);
        }
        _lettersPlacedThisTurn.add((row: row, col: col, letter: letter));
      });

      if (widget.onMovePlayed != null) {
        widget.onMovePlayed!(GameMove(letter: letter, row: row, col: col));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _zoomOnArea(row, col);
      });
    }
  }

  void _zoomOnArea(int row, int col) {
    // Dimensions
    const double cellSize = 40; // Assure-toi de la taille exacte
    const int zoomSize = 10; // 10×10 cases
    const double scale = 2.0; // Niveau de zoom

    // Calcul de la zone cible
    final double targetX = ((col - zoomSize ~/ 2) * cellSize).clamp(
      0,
      double.infinity,
    );
    final double targetY = ((row - zoomSize ~/ 2) * cellSize).clamp(
      0,
      double.infinity,
    );

    // Applique la transformation
    _boardController.value =
        Matrix4.identity()
          ..scale(scale)
          ..translate(-targetX, -targetY);
  }

  void _moveLetter(int fromIndex, int toIndex) {
    if (mounted) {
      setState(() {
        final letter = _playerLetters.removeAt(fromIndex);
        final adjustedIndex = fromIndex < toIndex ? toIndex - 1 : toIndex;
        _playerLetters.insert(adjustedIndex, letter);
      });
    }
  }

  void _removeLetter(int index) {
    if (mounted) {
      setState(() {
        _playerLetters.removeAt(index);
      });
    }
  }

  void _handleUndo() {
    if (mounted) {
      setState(() {
        for (final placed in _lettersPlacedThisTurn) {
          _board[placed.row][placed.col] = '';
        }
        _playerLetters = List.from(_initialRack);
        _lettersPlacedThisTurn.clear();
      });
    }
  }

  void _handleSubmit() {
    if (!mounted) return;

    setState(() {
      final int score = _lettersPlacedThisTurn.length;

      // Mettre à jour le score
      if (widget.gameState.isLeft) {
        widget.gameState.leftScore += score;
      } else {
        widget.gameState.rightScore += score;
      }

      // 🔁 Mettre à jour le plateau
      for (final placed in _lettersPlacedThisTurn) {
        final int row = placed.row;
        final int col = placed.col;
        final String letter = placed.letter;

        widget.gameState.board[row][col] = letter;
      }

      // Passer le tour
      widget.gameState.isLeft = !widget.gameState.isLeft;

      // Réinitialiser le rack
      _initialRack = List.from(_playerLetters);

      // 3. Compléter le rack avec des lettres du sac
      refillRack(7);

      // Nettoyer les lettres placées ce tour-ci
      _lettersPlacedThisTurn.clear();

      // 🔄 Transmettre le GameState mis à jour
      widget.onGameStateUpdated?.call(widget.gameState);
    });
  }

  void _showBagContents() {
    final bag = widget.gameState.bag;
    if (bag == null) return;

    final remaining = bag.remainingLetters;
    final content = remaining.entries
        .map((entry) => "${entry.key}: ${entry.value}")
        .join('\n');

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Lettres restantes dans le sac"),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fermer"),
              ),
            ],
          ),
    );
  }

  void refillRack(int rackSize) {
    int missing = rackSize - _playerLetters.length;
    if (missing > 0) {
      _playerLetters.addAll(widget.gameState.bag.drawLetters(missing));
    }
  }

  void onLetterReturned(String letter) {
    setState(() {
      _playerLetters.add(letter);
      // Supprime du plateau et de _lettersPlacedThisTurn
      final index = _lettersPlacedThisTurn.indexWhere(
        (pos) => pos.letter == letter,
      );
      if (index != -1) {
        final removedPos = _lettersPlacedThisTurn.removeAt(index);
        _board[removedPos.row][removedPos.col] = '';
      }
    });
  }

  @override
  void dispose() {
    ScrabbleNet().onGameStateReceived = null;
    _net.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble_chen ;-)")),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 167, 156, 13),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color:
                        widget.gameState.isLeft
                            ? const Color.fromARGB(255, 141, 23, 15)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    "${widget.gameState.leftName}: ${widget.gameState.leftScore}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.gameState.isLeft ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "vs",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color:
                        widget.gameState.isLeft
                            ? Colors.transparent
                            : const Color.fromARGB(255, 141, 23, 15),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18.0,
                    vertical: 4.0,
                  ),
                  child: Text(
                    "${widget.gameState.rightName}: ${widget.gameState.rightScore}",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color:
                          widget.gameState.isLeft ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            flex: 5,
            child: GestureDetector(
              onDoubleTap: () {
                // Réinitialiser la vue
                _boardController.value = Matrix4.identity();
              },
              child: InteractiveViewer(
                transformationController: _boardController,
                minScale: 1.0,
                maxScale: 3.0,
                child: buildScrabbleBoard(
                  board: _board,
                  playerLetters: _playerLetters,
                  onLetterPlaced: _handleLetterPlaced,
                  lettersPlacedThisTurn: _lettersPlacedThisTurn,
                  onLetterReturned: onLetterReturned,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: PlayerRack(
              letters: _playerLetters,
              onMove: _moveLetter,
              onRemoveLetter: _removeLetter,
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Annuler',
                onPressed: _handleUndo,
              ),
              IconButton(
                icon: const Icon(Icons.send),
                tooltip: 'Envoyer',
                onPressed: _handleSubmit,
              ),
              IconButton(
                icon: const Icon(Icons.inventory_2),
                tooltip: 'Voir le sac',
                onPressed: _showBagContents,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
