import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../models/dragged_letter.dart';
import '../models/placed_letter.dart';
import '../bonus.dart';
import '../constants.dart';

const int boardSize = 15;

Widget buildScrabbleBoard({
  required List<List<String>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required void Function(
    String letter,
    int row,
    int col,
    int? oldRow,
    int? oldCol,
  )
  onLetterPlaced,
  required void Function(String letter) onLetterReturned,
}) {
  DraggedLetter? currentlyDragged;

  return LayoutBuilder(
    builder: (context, constraints) {
      final tileSize = _calculateTileSize(context);

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
          final isPlacedThisTurn = cellLetterRecord != null;

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
                onLeave: (_) {
                  setState(() => isHovered = false);
                },
                onAcceptWithDetails: (details) {
                  final dragged = details.data;
                  final letter = dragged.letter;

                  if (debug) {
                    debugPrint('Lettre acceptée : $letter à ($row, $col)');
                  }

                  if (board[row][col].isEmpty) {
                    setState(() => isHovered = false);

                    onLetterPlaced(letter, row, col, dragged.row, dragged.col);
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
                                    ? Colors
                                        .amber[400] // Surbrillance des lettres posées ce tour
                                    : Colors
                                        .amber[200]) // Lettres posées avant ce tour
                                : bgColor,
                      ),
                      child: Center(
                        child:
                            cellLetter.isNotEmpty
                                ? (isPlacedThisTurn && !isCurrentlyDragged
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
                                      onDragEnd: (details) {
                                        if (!details.wasAccepted) {
                                          // 👉 la lettre vient du board, on ne la supprime pas
                                          // donc on NE fait rien, elle reste en place
                                        }
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
                                            highlight: isPlacedThisTurn,
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildLetterTile(
                                          cellLetter,
                                          size: tileSize * 3,
                                          highlight: isPlacedThisTurn,
                                        ),
                                      ),
                                      child: _buildLetterTile(
                                        cellLetter,
                                        size: tileSize,
                                        highlight: isPlacedThisTurn,
                                      ),
                                    )
                                    : _buildLetterTile(
                                      cellLetter,
                                      size: tileSize,
                                      highlight: false,
                                    ))
                                : Text(
                                  bonusLabel(bonus),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                  ),
                                ),
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
              ? Colors.amber[600]?.withOpacity(0.6)
              : (greyed ? Colors.amber[100] : Colors.amber[200]),
      border: Border.all(color: Colors.black),
    ),
    child: Stack(
      children: [
        Transform.translate(
          offset: const Offset(0, -3),
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
