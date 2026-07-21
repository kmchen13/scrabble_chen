import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:scrabble_P2P/services/dictionary.dart';

import 'package:scrabble_P2P/models/placed_letter.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';
import 'package:scrabble_P2P/score.dart';
import 'package:url_launcher/url_launcher.dart';
import '../bonus.dart';

const boardSize = 15;

typedef OnLetterPlacedCallback =
    void Function(String letter, int row, int col, int? oldRow, int? oldCol);

typedef OnLetterReturnedCallback = void Function(PlacedLetter placedLetter);

// ============================================================
// 1. Fonction pour créer un chemin octogonal
// ============================================================
Path _createOctagonShape(Size size) {
  final double w = size.width;
  final double h = size.height;
  final double ratio = 0.293; // 1 - cos(45°) ≈ 0.293

  final double x1 = 0;
  final double x2 = w * ratio;
  final double x3 = w * (1 - ratio);
  final double x4 = w;

  final double y1 = 0;
  final double y2 = h * ratio;
  final double y3 = h * (1 - ratio);
  final double y4 = h;

  return Path()
    ..moveTo(x2, y1)
    ..lineTo(x3, y1)
    ..lineTo(x4, y2)
    ..lineTo(x4, y3)
    ..lineTo(x3, y4)
    ..lineTo(x2, y4)
    ..lineTo(x1, y3)
    ..lineTo(x1, y2)
    ..close();
}

Future<void> openWiktionary(DictionaryService dictionary, String word) async {
  final canonical = dictionary.getCanonicalForm(word) ?? word;

  final url = Uri.parse(
    "https://fr.wiktionary.org/wiki/${Uri.encodeComponent(canonical)}",
  );

  await launchUrl(url, mode: LaunchMode.externalApplication);
}

// ============================================================
// 2. Widget principal du plateau
// ============================================================
Widget buildScrabbleBoard({
  required GlobalKey boardKey,
  required List<List<String>> board,
  required List<List<Map<String, dynamic>?>> boardJokerInfo,
  required DictionaryService dictionary,
  required List<PlacedLetter> lettersPlacedThisTurn,
  required OnLetterPlacedCallback onLetterPlaced,
  required OnLetterReturnedCallback onLetterReturned,
}) {
  DraggedLetter? currentlyDragged;

  return LayoutBuilder(
    builder: (context, constraints) {
      final tileSize = _calculateTileSize(context);
      final backgroundColor = const Color(
        0xFF1A2A3A,
      ); // Bleu nuit profond original
      final spacing = tileSize * 0.04;

      return Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(8),
        child: Center(
          child: SizedBox(
            width: tileSize * boardSize + spacing * (boardSize + 1),
            height: tileSize * boardSize + spacing * (boardSize + 1),
            child: GridView.builder(
              key: boardKey,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: boardSize,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
              ),
              itemCount: boardSize * boardSize,
              itemBuilder: (context, index) {
                final row = index ~/ boardSize;
                final col = index % boardSize;

                final cellLetterRecord = lettersPlacedThisTurn.firstWhereOrNull(
                  (e) => e.row == row && e.col == col,
                );

                final bool isJoker =
                    cellLetterRecord?.isJoker ??
                    (boardJokerInfo[row][col]?['isJoker'] as bool? ?? false);

                final String? jokerValue =
                    cellLetterRecord?.jokerValue ??
                    (boardJokerInfo[row][col]?['jokerValue'] as String?);

                final String cellLetter =
                    cellLetterRecord?.displayLetter ??
                    (isJoker && jokerValue != null
                        ? jokerValue
                        : board[row][col]);

                final bonus = bonusMap[row][col];
                final isPlacedThisTurn = cellLetterRecord != null;

                // Couleur de base de la case selon le bonus (charte originale)
                final baseColor = getColorForBonus(bonus);

                // Couleur des octogones plus foncée
                final bgColor =
                    cellLetter.isNotEmpty
                        ? (bonus != BonusType.none
                            ? baseColor.withOpacity(
                              0.85,
                            ) // Plus opaque pour les bonus
                            : const Color(
                              0xFF555555,
                            )) // Plus clair pour cases occupées
                        : (bonus != BonusType.none
                            ? baseColor.withOpacity(
                              0.35,
                            ) // Bonus visibles mais atténués
                            : const Color(
                              0xFF3A3A3A,
                            )); // Gris foncé pour cases vides

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
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (cellLetterRecord != null) {
                              onLetterReturned(cellLetterRecord);
                            }
                          },
                          onLongPress: () {
                            final word = getWordAtPosition(
                              board: board,
                              row: row,
                              col: col,
                            );

                            if (word != null) {
                              openWiktionary(dictionary, word);
                            }
                          },
                          child: CustomPaint(
                            painter: _OctagonPainter(
                              color: bgColor,
                              borderColor:
                                  isHovered
                                      ? Colors.white
                                      : (cellLetter.isNotEmpty
                                          ? Colors
                                              .grey
                                              .shade500 // Bordure visible pour cases occupées
                                          : Colors.grey.shade700),
                              borderWidth: isHovered ? 3.0 : 1.2,
                            ),
                            child: Container(
                              alignment: Alignment.center,
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
                                                  size: tileSize * 1.8,
                                                  highlight: isPlacedThisTurn,
                                                  isJoker: isJoker,
                                                  isStarBonus:
                                                      bonus == BonusType.star,
                                                ),
                                              ),
                                            ),
                                            childWhenDragging: Opacity(
                                              opacity: 0.3,
                                              child: _buildLetterTile(
                                                cellLetter,
                                                size: tileSize * 0.9,
                                                highlight: isPlacedThisTurn,
                                                isJoker: isJoker,
                                                isStarBonus:
                                                    bonus == BonusType.star,
                                              ),
                                            ),
                                            child: _buildLetterTile(
                                              cellLetter,
                                              size: tileSize * 0.9,
                                              highlight: isPlacedThisTurn,
                                              isJoker: isJoker,
                                              isStarBonus:
                                                  bonus == BonusType.star,
                                            ),
                                          )
                                          : _buildLetterTile(
                                            cellLetter,
                                            size: tileSize * 0.9,
                                            isJoker: isJoker,
                                            isStarBonus:
                                                bonus == BonusType.star,
                                          ))
                                      : Center(
                                        child: Text(
                                          bonusLabel(
                                            bonus,
                                          ).replaceAll('Lx2', 'L2'),
                                          style: TextStyle(
                                            fontSize: tileSize * 0.35,
                                            color:
                                                bonus != BonusType.none
                                                    ? Colors.white.withOpacity(
                                                      0.9,
                                                    )
                                                    : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Roboto',
                                            letterSpacing: 0.5,
                                          ),
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
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================
// 3. Calcul de la taille des cases
// ============================================================
double _calculateTileSize(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final maxWidth = screenWidth * 0.96;
  final maxHeight = screenHeight * 0.82;
  final maxSize = (maxWidth / boardSize).clamp(30.0, 65.0);
  return maxSize;
}

// ============================================================
// 4. Construction d'une tuile
// ============================================================
Widget _buildLetterTile(
  String letter, {
  required double size,
  bool highlight = false,
  bool isJoker = false,
  bool isStarBonus = false,
}) {
  final point = isJoker ? 0 : (letterPoints[letter.toUpperCase()] ?? 0);

  final tileColor =
      isJoker
          ? Colors.grey.shade300
          : (highlight
              ? Colors
                  .yellow
                  .shade100 // Couleur de surbrillance plus visible
              : Colors.white);

  return CustomPaint(
    painter: _LetterTilePainter(
      color: tileColor,
      borderColor:
          highlight
              ? Colors.amber
              : (isStarBonus ? const Color(0xFF00D2FF) : Colors.black87),
      borderWidth: highlight ? 3.0 : (isStarBonus ? 2.5 : 1.5),
      shadowColor:
          highlight
              ? Colors.amber
              : (isStarBonus ? const Color(0xFF00D2FF).withOpacity(0.5) : null),
      letter: letter,
      letterSize: size * 0.75,
      letterColor: isJoker ? Colors.black54 : Colors.black,
      point: point,
      pointSize: size * 0.3,
      showStar: isStarBonus,
      starSize: size * 0.2,
    ),
    child: SizedBox(width: size, height: size),
  );
}

// ============================================================
// 5. Painter pour dessiner les octogones du plateau
// ============================================================
class _OctagonPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;

  const _OctagonPainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final path = _createOctagonShape(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _OctagonPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}

// ============================================================
// 6. Painter pour les tuiles avec lettre (octogonales)
// ============================================================
class _LetterTilePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final Color? shadowColor;
  final String letter;
  final double letterSize;
  final Color letterColor;
  final int point;
  final double pointSize;
  final bool showStar;
  final double starSize;

  const _LetterTilePainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    this.shadowColor,
    required this.letter,
    required this.letterSize,
    required this.letterColor,
    required this.point,
    required this.pointSize,
    required this.showStar,
    required this.starSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Ombre portée pour les cases étoile
    if (shadowColor != null) {
      final shadowPaint =
          Paint()
            ..color = shadowColor!
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      final shadowPath = _createOctagonShape(size);
      canvas.drawPath(shadowPath, shadowPaint);
    }

    // Fond de la tuile
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    final borderPaint =
        Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth;

    final path = _createOctagonShape(size);
    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Lettre avec police Roboto
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontSize: letterSize,
          fontWeight: FontWeight.bold,
          color: letterColor,
          fontFamily: 'Roboto',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centrage vertical parfait
    canvas.save();
    canvas.translate(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Points à droite centrés verticalement
    if (point > 0) {
      final pointPainter = TextPainter(
        text: TextSpan(
          text: '$point',
          style: TextStyle(
            fontSize: pointSize,
            color: Colors.red,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(
        size.width - pointPainter.width - size.width * 0.06,
        (size.height - pointPainter.height) / 2,
      );
      pointPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Étoile pour les tuiles sur case Étoile (en haut à gauche)
    if (showStar) {
      const starPath = '⭐';
      final starPainter = TextPainter(
        text: TextSpan(
          text: starPath,
          style: TextStyle(fontSize: starSize, color: const Color(0xFF00D2FF)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(size.width * 0.05, size.height * 0.02);
      starPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _LetterTilePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.letter != letter ||
        oldDelegate.point != point;
  }
}
