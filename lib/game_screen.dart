import 'package:flutter/material.dart';
import 'models/board.dart';
import 'models/game_state.dart';
import 'models/player_rack.dart';
import 'models/bag.dart';
import 'network/scrabble_net.dart';
import 'services/settings_service.dart';
import 'services/utility.dart';
import 'services/game_initializer.dart';

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
    // Taille des cases (doit correspondre à celle du buildScrabbleBoard)
    const double cellSize = 40; // Peut être ajusté
    const int zoomSize = 12; // 12×12 cases visibles max
    const double scale = 15 / zoomSize; // Ajuste le zoom selon boardSize (15)

    // Dimensions totales du plateau
    final double boardSizePx = cellSize * 15;

    // Calcul des coordonnées ciblées pour centrer la zone autour (row,col)
    double targetX = (col - zoomSize ~/ 2) * cellSize;
    double targetY = (row - zoomSize ~/ 2) * cellSize;

    // Clamp pour ne pas sortir du plateau
    targetX = targetX.clamp(0, boardSizePx - (boardSizePx / scale));
    targetY = targetY.clamp(0, boardSizePx - (boardSizePx / scale));

    // Applique la transformation (zoom + translation)
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
      int score = 0;
      int wordMultiplier = 1;

      // Calcul du score des lettres placées
      for (final placed in _lettersPlacedThisTurn) {
        final String letter = placed.letter;
        final int row = placed.row;
        final int col = placed.col;

        int letterScore = letterPoints[letter] ?? 0;

        // Appliquer les bonus
        final bonus = bonusMap[row][col];
        switch (bonus) {
          case BonusType.doubleLetter:
            letterScore *= 2;
            break;
          case BonusType.tripleLetter:
            letterScore *= 3;
            break;
          case BonusType.doubleWord:
            wordMultiplier *= 2;
            break;
          case BonusType.tripleWord:
            wordMultiplier *= 3;
            break;
          case BonusType.none:
            break;
        }

        score += letterScore;

        widget.gameState.board[row][col] = letter;
      }

      score *= wordMultiplier;

      if (_lettersPlacedThisTurn.length == 7) {
        score += 50; // bonus Scrabble
      }

      if (widget.gameState.isLeft) {
        widget.gameState.leftScore += score;
      } else {
        widget.gameState.rightScore += score;
      }

      widget.gameState.isLeft = !widget.gameState.isLeft;

      _initialRack = List.from(_playerLetters);
      refillRack(7);
      _lettersPlacedThisTurn.clear();

      widget.onGameStateUpdated?.call(widget.gameState);

      // **Vérifier si la partie est terminée**
      if (_playerLetters.isEmpty && widget.gameState.bag.remainingCount == 0) {
        _showEndGamePopup();
      }
    });
  }

  void _showEndGamePopup() {
    String winner;
    if (widget.gameState.leftScore > widget.gameState.rightScore) {
      winner = widget.gameState.leftName;
    } else if (widget.gameState.rightScore > widget.gameState.leftScore) {
      winner = widget.gameState.rightName;
    } else {
      winner = "Égalité !";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            title: const Text("Fin de la partie"),
            content: Text(
              "Le gagnant est : $winner\n\nScore final :\n"
              "${widget.gameState.leftName}: ${widget.gameState.leftScore}\n"
              "${widget.gameState.rightName}: ${widget.gameState.rightScore}",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _startRematch();
                },
                child: const Text("Revanche"),
              ),
            ],
          ),
    );
  }

  void _startRematch() {
    final bool leftWon =
        widget.gameState.leftScore > widget.gameState.rightScore;
    final String newLeft =
        leftWon ? widget.gameState.rightName : widget.gameState.leftName;
    final String newRight =
        leftWon ? widget.gameState.leftName : widget.gameState.rightName;

    final newGameState = GameInitializer.createGame(
      isLeft: true, // Le nouveau joueur gauche commence
      leftName: newLeft,
      leftIP: '', // Peut être mis à jour
      leftPort: '',
      rightName: newRight,
      rightIP: '',
      rightPort: '',
    );

    setState(() {
      widget.gameState.copyFrom(newGameState);
      _board = newGameState.board.map((r) => List<String>.from(r)).toList();
      _playerLetters =
          newGameState.isLeft
              ? newGameState.leftLetters
              : newGameState.rightLetters;
      _initialRack = List.from(_playerLetters);
      _lettersPlacedThisTurn.clear();
    });

    widget.onGameStateUpdated?.call(widget.gameState);
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
    final bool isCurrentTurn =
        (widget.gameState.isLeft &&
            widget.gameState.leftName == settings.localUserName) ||
        (!widget.gameState.isLeft &&
            widget.gameState.rightName == settings.localUserName);

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
                // Réinitialiser la vue globale
                _boardController.value = Matrix4.identity();
              },
              child: InteractiveViewer(
                transformationController: _boardController,
                panEnabled: true,
                minScale: 1.0,
                maxScale: 15 / 12, // Zoom max pour afficher ~12 cases
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

              ElevatedButton(
                onPressed:
                    isCurrentTurn
                        ? _handleSubmit
                        : null, // désactivé si ce n’est pas son tour
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(
                    255,
                    141,
                    23,
                    15,
                  ), // désactivé
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // bords arrondis
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'Envoyer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
