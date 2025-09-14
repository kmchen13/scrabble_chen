import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/game_state\.dart';

class ScoreBar extends StatelessWidget {
  final GameState gameState;

  const ScoreBar({super.key, required this.gameState});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 167, 156, 13),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _scoreContainer(
            gameState.leftName,
            gameState.leftScore,
            gameState.isLeft,
          ),
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Colors.deepPurple,
            child: Text("vs", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 12),
          _scoreContainer(
            gameState.rightName,
            gameState.rightScore,
            !gameState.isLeft,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            "$score",
            style: const TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
