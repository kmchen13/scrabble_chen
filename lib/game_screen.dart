import 'package:flutter/material.dart';
import 'models/board.dart';
import 'models/game_state.dart';
import 'models/player_rack.dart';
import 'models/bag.dart';
import 'network/scrabble_net.dart';
import 'services/settings_service.dart';
import 'services/utility.dart';
import 'services/game_initializer.dart';
import 'models/dragged_letter.dart';
import 'models/placed_letter.dart';
import 'score.dart';
import 'services/game_storage.dart';

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
  final List<PlacedLetter> _lettersPlacedThisTurn = [];
  final TransformationController _boardController = TransformationController();
  bool _firstLetter = true;

  @override
  void initState() {
    super.initState();

    _net = widget.net;

    _net.onGameStateReceived = (newState) {
      if (!mounted) return;
      setState(() {
        widget.gameState.copyFrom(newState);
        _board =
            widget.gameState.board
                .map((row) => List<String>.from(row))
                .toList();
        _playerLetters =
            widget.gameState.isLeft
                ? widget.gameState.leftLetters
                : widget.gameState.rightLetters;
        _initialRack = List.from(_playerLetters);
        _lettersPlacedThisTurn
          ..clear()
          ..addAll(widget.gameState.lettersPlacedThisTurn);
      });
      _firstLetter = true;
    };

    _net.onGameOverReceived = (finalState) {
      if (!mounted) return;
      setState(() {
        widget.gameState.copyFrom(finalState); // si tu as une méthode update
      });
      _showEndGamePopup();
    };

    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();
    _playerLetters =
        widget.gameState.isLeft
            ? widget.gameState.leftLetters
            : widget.gameState.rightLetters;
    _initialRack = List.from(_playerLetters);

    _net.onError = (message) {
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('Erreur réseau'),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
        );
      }
    };

    saveSettings();
  }

  void onLetterPlaced(
    String letter,
    int row,
    int col,
    int? oldRow,
    int? oldCol,
  ) {
    setState(() {
      // Évite d’écraser une lettre déjà sur la case (par erreur externe)
      if (_board[row][col].isNotEmpty) return;

      if (_firstLetter) {
        // Premier coup joué ce tour => on vide les coups précédents
        _lettersPlacedThisTurn.clear();
        _firstLetter = false;
      }
      // Nettoie l'ancienne lettre
      if (oldRow != null && oldCol != null) {
        _board[oldRow][oldCol] = '';
        _lettersPlacedThisTurn.removeWhere(
          (e) => e.row == oldRow && e.col == oldCol && e.letter == letter,
        );
      }
      // Place la lettre à la nouvelle position
      _board[row][col] = letter;

      // Retire du rack uniquement si elle y est encore
      _playerLetters.remove(letter); // safe : remove ne crash pas si absente

      _lettersPlacedThisTurn.add(
        PlacedLetter(row: row, col: col, letter: letter, placedThisTurn: true),
      );
    });

    widget.onMovePlayed?.call(GameMove(letter: letter, row: row, col: col));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomOnArea(row, col);
    });
  }

  void _showBagContents() {
    final bag = widget.gameState.bag;
    final remaining = bag.remainingLetters;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Lettres restantes dans le sac"),
            content: SizedBox(
              width: 200,
              height: 300,
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 3.5, // Ajuste hauteur/largeur
                children:
                    remaining.entries.map((entry) {
                      return Text(
                        "${entry.key} : ${entry.value}",
                        style: const TextStyle(fontSize: 16),
                      );
                    }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fermer"),
              ),
            ],
          ),
    );
  }

  void _zoomOnArea(int row, int col) {
    const double cellSize = 40;
    const int zoomSize = 12;
    const double scale = 15 / zoomSize;

    final double boardSizePx = cellSize * 15;
    double targetX = (col - zoomSize ~/ 2) * cellSize;
    double targetY = (row - zoomSize ~/ 2) * cellSize;

    targetX = targetX.clamp(0, boardSizePx - (boardSizePx / scale));
    targetY = targetY.clamp(0, boardSizePx - (boardSizePx / scale));

    _boardController.value =
        Matrix4.identity()
          ..scale(scale)
          ..translate(-targetX, -targetY);
  }

  void _moveLetter(int fromIndex, int toIndex) {
    setState(() {
      final letter = _playerLetters.removeAt(fromIndex);
      final adjustedIndex = fromIndex < toIndex ? toIndex - 1 : toIndex;
      _playerLetters.insert(adjustedIndex, letter);
    });
  }

  void _handleUndo() {
    setState(() {
      for (final placed in _lettersPlacedThisTurn) {
        _board[placed.row][placed.col] = '';
        widget.gameState.bag.addLetter(placed.letter); // ✅ Restaure dans le sac
      }
      _playerLetters = List.from(_initialRack);
      _lettersPlacedThisTurn.clear();
    });
  }

  void _handleSubmit() {
    // Fusionne les lettres posées ce tour dans le plateau
    for (final placed in _lettersPlacedThisTurn) {
      _board[placed.row][placed.col] = placed.letter;
    }
    setState(() {
      final result = getWordsCreatedAndScore(
        board: widget.gameState.board,
        lettersPlacedThisTurn: _lettersPlacedThisTurn,
      );

      int totalScore = result.totalScore;

      // Bonus Scrabble : 7 lettres jouées
      if (_lettersPlacedThisTurn.length == 7) {
        totalScore += 50;
      }

      // Appliquer le score au joueur actif
      if (widget.gameState.isLeft) {
        widget.gameState.leftScore += totalScore;
      } else {
        widget.gameState.rightScore += totalScore;
      }

      // Placer définitivement les lettres sur le plateau et les retirer du sac
      for (final placed in _lettersPlacedThisTurn) {
        widget.gameState.board[placed.row][placed.col] = placed.letter;
        widget.gameState.bag.removeLetter(placed.letter);
      }
      // Transmettre les _lettersPlacedThisTurn pour surbrillance
      widget.gameState.lettersPlacedThisTurn = List.from(
        _lettersPlacedThisTurn,
      );

      // Tirer de nouvelles lettres
      refillRack(7);

      // Passer au tour suivant
      widget.gameState.isLeft = !widget.gameState.isLeft;

      widget.onGameStateUpdated?.call(widget.gameState);

      if (_playerLetters.isEmpty && widget.gameState.bag.remainingCount == 0) {
        _showEndGamePopup();
      }
    });
  }

  void refillRack(int rackSize) {
    int missing = rackSize - _playerLetters.length;
    if (missing > 0) {
      final drawn = widget.gameState.bag.drawLetters(missing);
      _playerLetters.addAll(drawn);

      // ✅ MISE À JOUR du GameState avec les nouvelles lettres
      if (widget.gameState.isLeft) {
        widget.gameState.leftLetters = List.from(_playerLetters);
      } else {
        widget.gameState.rightLetters = List.from(_playerLetters);
      }
    }
  }

  void _showEndGamePopup() {
    String winner =
        widget.gameState.leftScore == widget.gameState.rightScore
            ? "Égalité !"
            : (widget.gameState.leftScore > widget.gameState.rightScore
                ? widget.gameState.leftName
                : widget.gameState.rightName);

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
      isLeft: true,
      leftName: newLeft,
      leftIP: '',
      leftPort: 0,
      rightName: newRight,
      rightIP: '',
      rightPort: 0,
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
      appBar: AppBar(title: const Text("scrabble_P2P ;-)")),
      body: Column(
        children: [
          _buildScoreBar(),
          Expanded(
            flex: 5,
            child: GestureDetector(
              onDoubleTap: () => _boardController.value = Matrix4.identity(),
              child: InteractiveViewer(
                transformationController: _boardController,
                panEnabled: true,
                minScale: 1.0,
                maxScale: 15 / 12,
                child: buildScrabbleBoard(
                  board: _board,
                  lettersPlacedThisTurn:
                      _lettersPlacedThisTurn
                          .map(
                            (e) => PlacedLetter(
                              row: e.row,
                              col: e.col,
                              letter: e.letter,
                            ),
                          )
                          .toList(),
                  onLetterPlaced: onLetterPlaced,
                  onLetterReturned: _returnLetterToRack,
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
              onRemoveLetter: (i) => setState(() => _playerLetters.removeAt(i)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isCurrentTurn),
    );
  }

  Widget _buildScoreBar() {
    return Container(
      color: const Color.fromARGB(255, 167, 156, 13),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _scoreContainer(
            widget.gameState.leftName,
            widget.gameState.leftScore,
            widget.gameState.isLeft,
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.deepPurple,
            child: Text("vs", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          _scoreContainer(
            widget.gameState.rightName,
            widget.gameState.rightScore,
            !widget.gameState.isLeft,
          ),
        ],
      ),
    );
  }

  Widget _scoreContainer(String name, int score, bool active) {
    return Container(
      decoration: BoxDecoration(
        color:
            active
                ? const Color.fromARGB(255, 141, 23, 15)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      child: Text(
        "$name: $score",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: active ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isCurrentTurn) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.undo), onPressed: _handleUndo),
            ElevatedButton(
              onPressed: isCurrentTurn ? _handleSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 141, 23, 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                "Envoyer",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.inventory_2),
              onPressed: _showBagContents,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: "Sauvegarder la partie",
              onPressed: _saveCurrentGame,
            ),
          ],
        ),
      ),
    );
  }

  void _returnLetterToRack(String letter) {
    setState(() {
      _playerLetters.add(letter);
      final idx = _lettersPlacedThisTurn.indexWhere(
        (pos) => pos.letter == letter,
      );
      if (idx != -1) {
        final removed = _lettersPlacedThisTurn.removeAt(idx);
        _board[removed.row][removed.col] = '';
      }
    });
  }

  Future<void> _saveCurrentGame() async {
    await saveGameState(widget.gameState.toMap());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Partie sauvegardée")));
  }
}
