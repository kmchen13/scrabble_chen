// game_screen.dart
import 'package:flutter/material.dart';
import 'board.dart';
import 'models/game_state.dart';
import 'models/player_rack.dart';
import 'models/dragged_letter.dart';

class GameScreen extends StatefulWidget {
  final GameState gameState;

  const GameScreen({super.key, required this.gameState});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<String> _playerLetters;
  late List<List<String>> _board;

  @override
  void initState() {
    super.initState();
    _playerLetters = List.from(widget.gameState.playerLetters);
    _board =
        widget.gameState.board.map((row) => List<String>.from(row)).toList();
  }

  void _handleLetterPlaced(String letter, int row, int col) {
    setState(() {
      _board[row][col] = letter;
      final index = _playerLetters.indexOf(letter);
      if (index != -1) {
        _playerLetters.removeAt(
          index,
        ); // supprime la lettre du rack seulement ici
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scrabble")),
      body: Column(
        children: [
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
    );
  }
}
