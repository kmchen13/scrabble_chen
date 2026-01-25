import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';

import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';
import '../bonus.dart';

const boardSize = 15;

typedef OnLetterPlacedCallback =
    void Function(String letter, int row, int col, int? oldRow, int? oldCol);

typedef OnLetterReturnedCallback = void Function(PlacedLetter placedLetter);

Widget buildScrabbleBoard({
  required GlobalKey boardKey,
  required List<List<String>> board,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required OnLetterPlacedCallback onLetterPlaced,
  required OnLetterReturnedCallback onLetterReturned,
}) {
  DraggedLetter? currentlyDragged;

  return LayoutBuilder(
    builder: (context, constraints) {
      final tileSize = _calculateTileSize(context);

      return GridView.builder(
        key: boardKey,
        physics: const NeverScrollableScrollPhysics(),
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

          final bool isJoker = cellLetterRecord?.isJoker ?? false;
          final String cellLetter =
              cellLetterRecord?.displayLetter ?? board[row][col];

          final bonus = bonusMap[row][col];
          final bgColor = getColorForBonus(bonus);
          final isPlacedThisTurn = cellLetterRecord != null;

          bool isHovered = false;

          return StatefulBuilder(
            builder: (context, setState) {
              return DragTarget<DraggedLetter>(
                onWillAccept: (_) {
                  if (board[row][col].isEmpty) {
                    setState(() => isHovered = true);
                    return true;
                  }
                  return false;
                },
                onLeave: (_) => setState(() => isHovered = false),
                onAcceptWithDetails: (details) {
                  final dragged = details.data;
                  if (board[row][col].isEmpty) {
                    setState(() => isHovered = false);
                    onLetterPlaced(
                      dragged.letter,
                      row,
                      col,
                      dragged.row,
                      dragged.col,
                    );
                  }
                },
                builder: (context, _, __) {
                  final isCurrentlyDragged =
                      currentlyDragged != null &&
                      currentlyDragged!.row == row &&
                      currentlyDragged!.col == col;

                  return GestureDetector(
                    onTap: () {
                      if (cellLetterRecord != null) {
                        onLetterReturned(cellLetterRecord);
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
                          width: isHovered ? 3 : 1,
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
                                            highlight: isPlacedThisTurn,
                                            isJoker: isJoker,
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.3,
                                        child: _buildLetterTile(
                                          cellLetter,
                                          size: tileSize,
                                          highlight: isPlacedThisTurn,
                                          isJoker: isJoker,
                                        ),
                                      ),
                                      child: _buildLetterTile(
                                        cellLetter,
                                        size: tileSize,
                                        highlight: isPlacedThisTurn,
                                        isJoker: isJoker,
                                      ),
                                    )
                                    : _buildLetterTile(
                                      cellLetter,
                                      size: tileSize,
                                      isJoker: isJoker,
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
  return (boardWidth / boardSize).clamp(24, 40);
}

Widget _buildLetterTile(
  String letter, {
  required double size,
  bool highlight = false,
  bool isJoker = false,
}) {
  final point = isJoker ? 0 : (letterPoints[letter.toUpperCase()] ?? 0);
  if (isJoker) {
    print('Building tile for joker letter: "$letter"');
  }
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color:
          isJoker
              ? Colors.amber[400] // 🟫 joker plus sombre
              : (highlight
                  ? Colors.amber[600]?.withOpacity(0.6)
                  : Colors.amber[200]),
      border: Border.all(color: Colors.black),
    ),
    child: Stack(
      children: [
        Center(
          child: Text(
            letter,
            style: TextStyle(
              fontSize: size * 0.6,
              fontWeight: FontWeight.bold,
              color: isJoker ? Colors.black38 : Colors.black,
            ),
          ),
        ),
        if (point > 0)
          Positioned(
            bottom: 0,
            right: 2,
            child: Text(
              '$point',
              style: TextStyle(
                fontSize: size * 0.2,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    ),
  );
}
