// lib/screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/board.dart';
import 'package:scrabble_P2P/models/game_state\.dart';
import 'package:scrabble_P2P/models/player_rack.dart';
import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/models/move.dart';
import 'package:scrabble_P2P/network/scrabble_net.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/game_end.dart';
import 'package:scrabble_P2P/services/game_update.dart';
import 'package:scrabble_P2P/services/game_controller.dart';
import 'score_bar.dart';
import 'bottom_bar.dart';
import '../constants.dart';
import '../score.dart';

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
  static const String defaultTitle = "$appName -v$version";
  String _appBarTitle = defaultTitle;

  late ScrabbleNet _net;
  late GameState _gameState;
  late List<String> _playerLetters;
  final TransformationController _boardController = TransformationController();
  bool _firstLetter = true;
  late GameController _controller;

  _loadSavedGame() async {
    final saved = await gameStorage.load(
      GameStorage.buildKey(
        widget.gameState.partnerFrom(settings.localUserName),
      ),
    );
    setState(() {
      _gameState = saved ?? _gameState;
    });
  }

  @override
  void initState() {
    super.initState();

    _loadSavedGame();
    _net = widget.net;
    _gameState = widget.gameState;

    // initialize local arrays from initial state (will be overwritten by _applyIncomingState)
    _gameState.board =
        _gameState.board.map((r) => List<String>.from(r)).toList();
    _playerLetters = _gameState.localRack(settings.localUserName);

    _controller = GameController(
      net: _net,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onGameOver: (state) => onShowEndGameRequested(state),
    );

    final handler = GameUpdateHandler(
      net: _net,
      context: context,
      applyIncomingState: _applyIncomingState,
      showEndGamePopup: () => onShowEndGameRequested(_gameState),
      mounted: mounted,
    );
    handler.attach();

    if (_gameState != null) {
      _applyIncomingState(_gameState, updateUI: true);
    } else {
      _applyIncomingState(_gameState, updateUI: true);
    }

    saveSettings();
  }

  void onShowEndGameRequested(GameState finalState) {
    GameEndService.showEndGamePopup(
      context: context,
      finalState: finalState,
      net: _net,
      onRematchStarted: (newGameState) {
        if (!mounted) return;
        setState(() {
          _gameState = newGameState;
          _gameState.lettersPlacedThisTurn.clear();
          _gameState.board =
              newGameState.board.map((r) => List<String>.from(r)).toList();
          _playerLetters = newGameState.localRack(settings.localUserName);
        });
        // Inform parent that game state changed (if desired)
        widget.onGameStateUpdated?.call(_gameState);
      },
    );
  }

  void _applyIncomingState(GameState newState, {required bool updateUI}) {
    // copy into the _gameState to keep shared model consistent
    _gameState.copyFrom(newState);

    // update local UI copies
    _gameState = _gameState;
    _gameState.board =
        _gameState.board.map((r) => List<String>.from(r)).toList();
    _playerLetters = _gameState.localRack(settings.localUserName);

    // lettersPlacedThisTurn is déjà dans _gameState
    _gameState.lettersPlacedThisTurn
      ..clear()
      ..addAll(_gameState.lettersPlacedThisTurn);

    // reset zoom and flags
    _boardController.value = Matrix4.identity();
    _firstLetter = true;

    if (updateUI && mounted) {
      setState(() => _appBarTitle = defaultTitle);
    }
  }

  void onLetterPlaced(
    String letter,
    int row,
    int col,
    int? oldRow,
    int? oldCol,
  ) {
    setState(() {
      // protect against overwriting an occupied cell
      if (_gameState.board[row][col].isNotEmpty) return;

      if (_firstLetter) {
        // first letter placed this turn: clear any previous turn placements
        clearLettersPlacedThisTurn();
        _firstLetter = false;
      }

      // remove from previous position if moved on board
      if (oldRow != null && oldCol != null) {
        clearBoard(oldRow, oldCol);
        _gameState.lettersPlacedThisTurn.removeWhere(
          (e) => e.row == oldRow && e.col == oldCol && e.letter == letter,
        );
      }

      // place letter visually & in shared state
      _gameState.board[row][col] = _gameState.board[row][col] = letter;

      // remove from local rack if present
      _playerLetters.remove(letter);

      // record placement for this turn
      _gameState.lettersPlacedThisTurn.add(
        PlacedLetter(row: row, col: col, letter: letter, placedThisTurn: true),
      );

      _updateTitleWithProvisionalScore();
    });

    widget.onMovePlayed?.call(GameMove(letter: letter, row: row, col: col));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _zoomOnArea(row, col);
    });
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

  void _updateTitleWithProvisionalScore() {
    if (_gameState.lettersPlacedThisTurn.isEmpty) {
      setState(() => _appBarTitle = defaultTitle);
      return;
    }
    final result = getWordsCreatedAndScore(
      board: _gameState.board,
      lettersPlacedThisTurn: _gameState.lettersPlacedThisTurn,
    );
    final int score = result.totalScore;
    setState(() => _appBarTitle = "Score provisoire : $score");
  }

  void clearBoard(int row, int col) {
    setState(() {
      _gameState.board[row][col] = _gameState.board[row][col] = '';
    });
  }

  void clearLettersPlacedThisTurn() {
    setState(() {
      _gameState.lettersPlacedThisTurn.clear();
      _gameState.lettersPlacedThisTurn.clear();
    });
  }

  void _returnLetterToRack(String letter) {
    setState(() {
      _updateTitleWithProvisionalScore();
      _playerLetters.add(letter);
      final idx = _gameState.lettersPlacedThisTurn.indexWhere(
        (pos) => pos.letter == letter,
      );
      if (idx != -1) {
        final removed = _gameState.lettersPlacedThisTurn.removeAt(idx);
        clearBoard(removed.row, removed.col);
      }
    });
  }

  @override
  void dispose() {
    _net.onGameStateReceived = null;
    _net.onGameOverReceived = null;
    _net.onError = null;
    _net.onConnectionClosed = null;
    _net.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // compute whether it's the local player's turn
    final bool isCurrentTurn =
        (_gameState.isLeft && _gameState.leftName == settings.localUserName) ||
        (!_gameState.isLeft && _gameState.rightName == settings.localUserName);

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Column(
        children: [
          ScoreBar(gameState: _gameState),
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
                  board: _gameState.board,
                  lettersPlacedThisTurn:
                      _gameState.lettersPlacedThisTurn
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
                  _gameState.lettersPlacedThisTurn.removeWhere(
                    (placed) => placed.row == row && placed.col == col,
                  );
                });
              },
              onRemoveLetter: (i) => setState(() => _playerLetters.removeAt(i)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        canSubmit: _gameState.lettersPlacedThisTurn.isNotEmpty && isCurrentTurn,
        canUndo: _gameState.lettersPlacedThisTurn.isNotEmpty && isCurrentTurn,
        onQuit: () async {
          final userName = settings.localUserName;
          final partner = _gameState.partnerFrom(userName);
          // ensure quit completes before clearing / navigating
          await widget.net.quit(userName, partner);
          await gameStorage.delete(partner);
          if (context.mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        },
        onSubmit: () async {
          // call controller to handle game logic; then notify parent & refresh UI
          _controller.handleSubmit(
            state: _gameState,
            lettersThisTurn: _gameState.lettersPlacedThisTurn,
            playerRack: _playerLetters,
          );
          // ensure parent is notified (network already sent by controller)
          widget.onGameStateUpdated?.call(_gameState);
        },
        onUndo: () {
          _controller.handleUndo(
            state: _gameState,
            lettersThisTurn: _gameState.lettersPlacedThisTurn,
            playerRack: _playerLetters,
          );
          // update provisional title
          _updateTitleWithProvisionalScore();
        },
        onShowBag: () => _controller.handleShowBag(context, _gameState),
      ),
    );
  }
}
