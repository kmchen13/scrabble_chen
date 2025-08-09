import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/dragged_letter.dart';
import 'package:collection/collection.dart';
import '../bonus.dart';

const int boardSize = 15;

Widget buildScrabbleBoard({
  required List<List<String>> board,
  required List<({int row, int col, String letter})> lettersPlacedThisTurn,
  required void Function(String letter, int row, int col) onLetterPlaced,
  required void Function(String letter) onLetterReturned,
}) {
  bool _debug = true;
  DraggedLetter? currentlyDragged;

  return LayoutBuilder(
    builder: (context, constraints) {
      final tileSize = _calculateTileSize(context); // ← dynamique

      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: boardSize,
        ),
        itemCount: boardSize * boardSize,
        itemBuilder: (context, index) {
          final row = index ~/ boardSize;
          final col = index % boardSize;
          final cellLetterRecord = lettersPlacedThisTurn.firstWhereOrNull(
            (e) => e.row == row && e.col == col,
          );
          final cellLetter = cellLetterRecord?.letter ?? board[row][col];

          final bonus = bonusMap[row][col];
          final bgColor = getColorForBonus(bonus);

          final isPlacedThisTurn = lettersPlacedThisTurn.any(
            (pos) => pos.row == row && pos.col == col,
          );

          bool isHovered = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return DragTarget<DraggedLetter>(
                onWillAccept: (data) {
                  if (board[row][col].isEmpty) {
                    setState(() => isHovered = true);
                    return true;
                  }
                  return false;
                },
                onLeave: (data) {
                  setState(() => isHovered = false);
                },
                onAcceptWithDetails: (details) {
                  final dragged = details.data;
                  final letter = dragged.letter;
                  if (_debug) {
                    debugPrint('Lettre acceptée : ${dragged.letter} à ($row, $col)');
                  }

                  if (board[row][col].isEmpty) {
                    setState(() => isHovered = false);

                    // Nettoie l'ancienne position
                    if (dragged.row != null && dragged.col != null) {
                      board[dragged.row!][dragged.col!] = '';
                    }

                    // Supprime l’ancienne entrée si existe
                    if (dragged.row != null && dragged.col != null) {
                      lettersPlacedThisTurn.removeWhere(
                        (e) =>
                            e.row == dragged.row &&
                            e.col == dragged.col &&
                            e.letter == dragged.letter,
                      );
                    }

                    // Ajoute la nouvelle position
                    lettersPlacedThisTurn.add((
                      row: row,
                      col: col,
                      letter: letter,
                    ));
                    onLetterPlaced(letter, row, col);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isCurrentlyDragged =
                      currentlyDragged != null &&
                      currentlyDragged!.row == row &&
                      currentlyDragged!.col == col;

                  return GestureDetector(
                    onTap: () {
                      if (cellLetterRecord != null) {
                        onLetterReturned(cellLetterRecord.letter);
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              isHovered
                                  ? Colors.white
                                  : (cellLetter.isNotEmpty
                                      ? bgColor
                                      : Colors.grey),
                          width: isHovered ? 3.0 : 1.0,
                        ),
                        color:
                            cellLetter.isNotEmpty
                                ? (isPlacedThisTurn
                                    ? Colors.amber[400]
                                    : Colors.amber[200])
                                : bgColor,
                      ),
                      child: Center(
                        child:
                            (cellLetter.isNotEmpty && !isCurrentlyDragged)
                                ? Draggable<DraggedLetter>(
                                  data: DraggedLetter(
                                    letter: cellLetter,
                                    fromIndex: -1,
                                    row: row,
                                    col: col,
                                  ),
                                  onDragStarted: () {
                                    HapticFeedback.mediumImpact();
                                    currentlyDragged = DraggedLetter(
                                      letter: cellLetter,
                                      fromIndex: -1,
                                      row: row,
                                      col: col,
                                    );
                                    setState(() {});
                                  },
                                  onDragEnd: (_) {
                                    currentlyDragged = null;
                                    setState(() {});
                                  },
                                  feedback: Opacity(
                                    opacity: 0.7,
                                    child: Transform.scale(
                                      scale: 1.4,
                                      child: _buildLetterTile(
                                        cellLetter,
                                        size: tileSize * 2,
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.3,
                                    child: _buildLetterTile(
                                      cellLetter,
                                      size: tileSize * 3,
                                    ),
                                  ),
                                  child: _buildLetterTile(
                                    cellLetter,
                                    size: tileSize,
                                    greyed: isPlacedThisTurn,
                                  ),
                                )
                                : (cellLetter.isEmpty
                                    ? Text(
                                      bonusLabel(bonus),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const SizedBox.shrink()),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

double _calculateTileSize(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final boardWidth = screenWidth * 0.95;
  final tileSize = boardWidth / boardSize;
  return tileSize.clamp(24, 40);
}

Widget _buildLetterTile(
  String letter, {
  required double size,
  bool greyed = false,
  bool highlight = false,
}) {
  final point = letterPoints[letter.toUpperCase()] ?? 0;

  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color:
          highlight
              ? Colors.amber[800]?.withOpacity(0.6)
              : (greyed ? Colors.amber[100] : Colors.amber[200]),
      border: Border.all(color: Colors.black),
    ),
    child: Stack(
      children: [
        Transform.translate(
          offset: Offset(0, -3), // Ajustez cette valeur pour monter la lettre
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        if (point > 0)
          Positioned(
            bottom: 0,
            right: 1,
            child: Text(
              '$point',
              style: TextStyle(
                fontSize: size * 0.2,
                color: Colors.black87,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
}
