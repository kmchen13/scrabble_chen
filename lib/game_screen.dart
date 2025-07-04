import 'package:flutter/material.dart';
import 'board.dart';
import 'models/game_state.dart';
import 'models/player_rack.dart';

import 'services/settings_service.dart';

typedef MovePlayedCallback = void Function(GameMove move);

/// Structure représentant un coup joué.
class GameMove {
  final String letter;
  final int row;
  final int col;

  GameMove({required this.letter, required this.row, required this.col});
}

class GameScreen extends StatefulWidget {
  final GameState gameState;
  final String localUserName;
  final String remoteUserName;
  final MovePlayedCallback? onMovePlayed;

  const GameScreen({
    super.key,
    required this.gameState,
    required this.localUserName,
    required this.remoteUserName,
    this.onMovePlayed,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> _playerLetters;
  late List<List<String>> _board;
  late List<String> _initialRack;
  final List<({int row, int col, String letter})> _lettersPlacedThisTurn = [];

  @override
  void initState() {
    super.initState();
    _playerLetters = List.from(widget.gameState.playerLetters);
    _initialRack = List.from(_playerLetters);
    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();
  }

  bool _isLocalPlayersTurn() {
    final isClient = settings.communicationMode == 'local';
    return widget.gameState.isClientTurn == isClient;
  }

  void _handleLetterPlaced(String letter, int row, int col) {
    if (!_isLocalPlayersTurn()) return;
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
  }

  void _moveLetter(int fromIndex, int toIndex) {
    setState(() {
      final letter = _playerLetters.removeAt(fromIndex);
      final adjustedIndex = fromIndex < toIndex ? toIndex - 1 : toIndex;
      _playerLetters.insert(adjustedIndex, letter);
    });
  }

  void _removeLetter(int index) {
    setState(() {
      _playerLetters.removeAt(index);
    });
  }

  void _handleUndo() {
    if (!_isLocalPlayersTurn()) return;
    setState(() {
      for (final placed in _lettersPlacedThisTurn) {
        _board[placed.row][placed.col] = '';
      }
      _playerLetters = List.from(_initialRack);
      _lettersPlacedThisTurn.clear();
    });
  }

  void _handleSubmit() {
    if (!_isLocalPlayersTurn()) return;
    setState(() {
      final int score = _lettersPlacedThisTurn.length;

      if (widget.gameState.isClientTurn) {
        widget.gameState.clientScore += score;
      } else {
        widget.gameState.hostScore += score;
      }

      // Retirer les lettres placées du rack initial
      for (final placed in _lettersPlacedThisTurn) {
        _initialRack.remove(placed.letter);
      }

      // Tirer des lettres depuis le sac pour compléter à 7
      final bag = widget.gameState.bag;
      if (bag != null) {
        final newLetters = bag.drawLetters(7 - _playerLetters.length);
        _playerLetters.addAll(newLetters);
        widget.gameState.playerLetters = List.from(_playerLetters); // MAJ rack
      }

      widget.gameState.isClientTurn = !widget.gameState.isClientTurn;

      _initialRack = List.from(_playerLetters);
      _lettersPlacedThisTurn.clear();
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

  @override
  Widget build(BuildContext context) {
    final isClient = settings.communicationMode == 'local';
    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble")),
      body: Column(
        children: [
          Container(
            color: const Color.fromARGB(255, 167, 156, 13),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${widget.localUserName}: ${isClient ? widget.gameState.clientScore : widget.gameState.hostScore}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        _isLocalPlayersTurn()
                            ? const Color.fromARGB(255, 104, 62, 0)
                            : Colors.black,
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
                Text(
                  "${widget.remoteUserName}: ${isClient ? widget.gameState.hostScore : widget.gameState.clientScore}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: !_isLocalPlayersTurn() ? Colors.green : Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            flex: 5,
            child: buildScrabbleBoard(
              board: _board,
              playerLetters: _playerLetters,
              onLetterPlaced: _handleLetterPlaced,
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
