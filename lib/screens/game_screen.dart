import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/board.dart';
import 'package:scrabble_P2P/models/game_state.dart';
import 'package:scrabble_P2P/models/player_rack.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_initializer.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:scrabble_P2P/services/game_update.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/screens/home_screen.dart';
import 'package:scrabble_P2P/score.dart';
import 'package:scrabble_P2P/constants.dart';

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
  String _appBarTitle = defaultTitle;
  late ScrabbleNet _net;
  late List<String> _playerLetters;
  late List<List<String>> _board;
  late List<String> _initialRack;
  final List<PlacedLetter> _lettersPlacedThisTurn = [];
  final TransformationController _boardController = TransformationController();
  bool _firstLetter = true;
  late final GameUpdateHandler _updateHandler;

  void _applyGameState(GameState newState) {
    _appBarTitle = defaultTitle;

    widget.gameState.copyFrom(newState);

    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();

    _playerLetters = widget.gameState.localRack(settings.localUserName);

    _initialRack = List.from(_playerLetters);

    _lettersPlacedThisTurn
      ..clear()
      ..addAll(widget.gameState.lettersPlacedThisTurn);

    _boardController.value = Matrix4.identity();
    _firstLetter = true;
  }

  @override
  void initState() {
    super.initState();

    _net = widget.net;

    _updateHandler = GameUpdateHandler(
      net: _net,
      context: context,
      applyIncomingState: (newState, {required bool updateUI}) {
        _applyGameState(newState);
        if (updateUI) {
          setState(() {});
        }
      },
      showEndGamePopup: _showEndGamePopup,
      mounted: mounted,
    );
    _updateHandler.attach();

    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();

    _playerLetters = widget.gameState.localRack(settings.localUserName);
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

    widget.net.onConnectionClosed = () async {
      if (mounted) {
        if (debug)
          print("${logHeader('GameScreen')} Le partenaire a abandonné");
        final partner = widget.gameState.partnerFrom(settings.localUserName);
        await gameStorage.delete(partner);

        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text("$partner a quitté la partie"),
            action: SnackBarAction(
              label: 'Fermer',
              onPressed: () => messenger.hideCurrentSnackBar(),
            ),
            duration: const Duration(hours: 1),
          ),
        );

        Navigator.of(context).popUntil((route) => route.isFirst);
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
        clearLettersPlacedThisTurn();
        _firstLetter = false;
      }
      // Nettoie l'ancienne lettre
      if (oldRow != null && oldCol != null) {
        clearBoard(oldRow, oldCol);
        _lettersPlacedThisTurn.removeWhere(
          (e) => e.row == oldRow && e.col == oldCol && e.letter == letter,
        );
      }
      // Place la lettre à la nouvelle position
      widget.gameState.board[row][col] = _board[row][col] = letter;

      // Retire du rack uniquement si elle y est encore
      _playerLetters.remove(letter); // safe : remove ne crash pas si absente

      _lettersPlacedThisTurn.add(
        PlacedLetter(row: row, col: col, letter: letter, placedThisTurn: true),
      );

      _updateTitleWithProvisionalScore();
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
    // sécurité si les indices sont hors bornes
    if (fromIndex < 0 || fromIndex >= _playerLetters.length) return;
    if (toIndex < 0) toIndex = 0;
    if (toIndex > _playerLetters.length) toIndex = _playerLetters.length;

    setState(() {
      final letter = _playerLetters.removeAt(fromIndex);
      final adjustedIndex = fromIndex < toIndex ? toIndex - 1 : toIndex;
      _playerLetters.insert(adjustedIndex, letter);
    });
  }

  void _handleUndo() {
    if (_firstLetter) return;
    setState(() {
      for (final placed in _lettersPlacedThisTurn) {
        clearBoard(placed.row, placed.col);
        widget.gameState.bag.addLetter(placed.letter); // ✅ Restaure dans le sac
      }
      _playerLetters = List.from(_initialRack);
      clearLettersPlacedThisTurn();
      _updateTitleWithProvisionalScore();
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

      // ⚡️ Envoyer le nouvel état de jeu
      widget.onGameStateUpdated?.call(widget.gameState);

      // ✅ Réinitialiser _lettersPlacedThisTurn pour neutraliser _returnLetterToRack
      clearLettersPlacedThisTurn();

      gameStorage.save(widget.gameState);

      // La partie prend fin lorsqu'il n'y a plus de lettres dans le sac et queles 2 joueurs ont joué le même nombre de tours
      if (widget.gameState.bag.remainingCount == 0 &&
          (widget.gameState.isLeft &&
              (settings.localUserName == widget.gameState.rightName))) {
        _showEndGamePopup();
        _net.sendGameOver(widget.gameState);
      }

      setState(() => _appBarTitle = defaultTitle);
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
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text("Retour à l'accueil"),
              ),
            ],
          ),
    );
  }

  void _startRematch() {
    _appBarTitle = defaultTitle;

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
    if (!mounted) return;
    setState(() {
      widget.gameState.copyFrom(newGameState);
      _board = newGameState.board.map((r) => List<String>.from(r)).toList();
      _playerLetters = widget.gameState.localRack(settings.localUserName);
      _initialRack = List.from(_playerLetters);
      clearLettersPlacedThisTurn();
    });

    widget.onGameStateUpdated?.call(widget.gameState);
  }

  @override
  void dispose() {
    _updateHandler.detach();
    _net.onError = null;
    _net.onConnectionClosed = null;
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
      appBar: AppBar(title: Text(_appBarTitle)),
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
              onMove: (fromIndex, toIndex) {
                setState(() {
                  final letter = _playerLetters.removeAt(fromIndex);
                  _playerLetters.insert(toIndex, letter);
                });
              },
              onAddLetter: (String letter, {int? hoveredIndex}) {
                // Utilisez un paramètre nommé
                setState(() {
                  if (hoveredIndex != null) {
                    _playerLetters.insert(hoveredIndex, letter);
                  } else {
                    _playerLetters.add(letter);
                  }
                });
              },
              onRemoveFromBoard: (row, col) {
                setState(() {
                  clearBoard(row, col);
                  _lettersPlacedThisTurn.removeWhere(
                    (placed) => placed.row == row && placed.col == col,
                  );
                });
              },
              onRemoveLetter: (i) => setState(() => _playerLetters.removeAt(i)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(isCurrentTurn),
    );
  }

  Widget _buildScoreBar() {
    final nameDspl = settings.nameDisplayLimit;
    final screenWidth = MediaQuery.of(context).size.width;

    // Ajustement de la taille de police en fonction de la largeur de l'écran
    double nameFontSize;
    if (screenWidth < 350) {
      nameFontSize = 12;
    } else if (screenWidth < 500) {
      nameFontSize = 14;
    } else {
      nameFontSize = 16;
    }

    // Limite les noms à nameDspl caractères
    String shortLeftName =
        widget.gameState.leftName.length > nameDspl
            ? widget.gameState.leftName.substring(0, nameDspl)
            : widget.gameState.leftName;
    String shortRightName =
        widget.gameState.rightName.length > nameDspl
            ? widget.gameState.rightName.substring(0, nameDspl)
            : widget.gameState.rightName;

    return Container(
      color: const Color.fromARGB(255, 167, 156, 13),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _scoreContainer(
            "$shortLeftName: ${widget.gameState.leftScore}",
            widget.gameState.isLeft,
            fontSize: nameFontSize,
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.deepPurple,
            child: Text("vs", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          _scoreContainer(
            "$shortRightName: ${widget.gameState.rightScore}",
            !widget.gameState.isLeft,
            fontSize: nameFontSize,
          ),
        ],
      ),
    );
  }

  Widget _scoreContainer(
    String text,
    bool isActive, {
    required double fontSize,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[700] : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
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
              icon: const Icon(Icons.exit_to_app),
              onPressed: () async {
                final userName = settings.localUserName;
                final partner = widget.gameState.partnerFrom(userName);
                try {
                  // ensure quit completes before clearing / navigating
                  await widget.net.quit(userName, partner);
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  print("⛔ Erreur abandon: $e");
                }

                // Supprime le GameState local
                gameStorage.delete(partner);

                // Retourne à l'écran d’accueil
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),

            IconButton(
              icon: const Icon(Icons.inventory_2),
              onPressed: _showBagContents,
            ),
          ],
        ),
      ),
    );
  }

  void _returnLetterToRack(String letter) {
    setState(() {
      _updateTitleWithProvisionalScore();

      _playerLetters.add(letter);
      final idx = _lettersPlacedThisTurn.indexWhere(
        (pos) => pos.letter == letter,
      );
      if (idx != -1) {
        final removed = _lettersPlacedThisTurn.removeAt(idx);
        clearBoard(removed.row, removed.col);
      }
    });
  }

  void _updateTitleWithProvisionalScore() {
    if (_lettersPlacedThisTurn.isEmpty) {
      setState(() => _appBarTitle = defaultTitle);
      return;
    }
    final result = getWordsCreatedAndScore(
      board: widget.gameState.board,
      lettersPlacedThisTurn: _lettersPlacedThisTurn,
    );
    int score = result.totalScore;
    setState(() => _appBarTitle = "Score provisoire : $score");
  }

  void clearBoard(row, col) {
    setState(() {
      widget.gameState.board[row][col] = _board[row][col] = '';
    });
  }

  void clearLettersPlacedThisTurn() {
    setState(() {
      _lettersPlacedThisTurn.clear();
      widget.gameState.lettersPlacedThisTurn.clear();
    });
  }
}
