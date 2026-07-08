import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';
import 'package:scrabble_P2P/score.dart';

class PlayerRack extends StatelessWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter, {int? hoveredIndex})? onAddLetter;
  final void Function(int row, int col)? onRemoveFromBoard;

  const PlayerRack({
    Key? key,
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
    this.onRemoveFromBoard,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return _PlayerRackInternal(
      letters: letters,
      onMove: onMove,
      onRemoveLetter: onRemoveLetter,
      onAddLetter: onAddLetter,
      onRemoveFromBoard: onRemoveFromBoard,
    );
  }
}

class _PlayerRackInternal extends StatefulWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter, {int? hoveredIndex})? onAddLetter;
  final void Function(int row, int col)? onRemoveFromBoard;

  const _PlayerRackInternal({
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
    this.onRemoveFromBoard,
  });

  @override
  State<_PlayerRackInternal> createState() => _PlayerRackInternalState();
}

class _PlayerRackInternalState extends State<_PlayerRackInternal> {
  int? _hoveredIndex;
  DraggedLetter? _dragging;

  static const int rackSlots = 7;

  @override
  Widget build(BuildContext context) {
    final tileSize = _calculateTileSize(context);
    final previewLetters = _computePreviewLetters();

    return SizedBox(
      height: tileSize + 16,
      child: Center(
        child: Stack(
          children: [
            // Rack VISUEL (7 tuiles octogonales)
            SizedBox(
              width: rackSlots * tileSize,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(previewLetters.length, (index) {
                  final letter = previewLetters[index];

                  return DragTarget<DraggedLetter>(
                    onWillAccept: (data) {
                      setState(() {
                        _hoveredIndex = index;
                        _dragging = data;
                      });
                      return true;
                    },
                    onLeave: (_) {
                      setState(() {
                        _hoveredIndex = null;
                        _dragging = null;
                      });
                    },
                    onAccept: (data) {
                      setState(() {
                        _dragging = null;
                      });

                      if (data.fromIndex >= 0) {
                        widget.onMove?.call(data.fromIndex, index);
                      } else {
                        widget.onAddLetter?.call(
                          data.letter,
                          hoveredIndex: _hoveredIndex,
                        );
                        if (widget.onRemoveFromBoard != null &&
                            data.row != null &&
                            data.col != null) {
                          widget.onRemoveFromBoard!(data.row!, data.col!);
                        }
                      }
                    },
                    builder: (_, __, ___) {
                      return Draggable<DraggedLetter>(
                        data: DraggedLetter(letter: letter, fromIndex: index),
                        onDragStarted: () => HapticFeedback.mediumImpact(),
                        onDragEnd: (details) {
                          if (!details.wasAccepted) {
                            setState(() {
                              if (!widget.letters.contains(letter)) {
                                widget.letters.insert(index, letter);
                              }
                            });
                          }
                          setState(() {
                            _dragging = null;
                            _hoveredIndex = null;
                          });
                        },
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.4,
                            child: Opacity(
                              opacity: 0.7,
                              child: _buildLetterTile(letter, tileSize),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.0,
                          child: _buildLetterTile(letter, tileSize),
                        ),
                        child: _buildLetterTile(letter, tileSize),
                      );
                    },
                  );
                }),
              ),
            ),

            // Zone INVISIBLE pour drop après la dernière tuile
            Positioned(
              right: -tileSize,
              top: 0,
              bottom: 0,
              width: tileSize,
              child: DragTarget<DraggedLetter>(
                onWillAccept: (_) {
                  setState(() {
                    _hoveredIndex = previewLetters.length;
                  });
                  return true;
                },
                onLeave: (_) {
                  setState(() {
                    _hoveredIndex = null;
                  });
                },
                onAccept: (data) {
                  if (data.fromIndex >= 0) {
                    widget.onMove?.call(data.fromIndex, previewLetters.length);
                  } else {
                    widget.onAddLetter?.call(
                      data.letter,
                      hoveredIndex: previewLetters.length,
                    );
                  }
                },
                builder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _computePreviewLetters() {
    if (_hoveredIndex == null || _dragging == null) {
      return List.of(widget.letters);
    }

    final preview = List.of(widget.letters);
    late String dragged;

    if (_dragging!.fromIndex >= 0 && _dragging!.fromIndex < preview.length) {
      dragged = preview.removeAt(_dragging!.fromIndex);
    } else {
      dragged = _dragging!.letter;
    }

    preview.insert(_hoveredIndex!.clamp(0, preview.length), dragged);

    return preview;
  }

  double _calculateTileSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rackWidth = screenWidth * 0.9;
    final size = rackWidth / rackSlots;
    return size.clamp(36.0, 56.0);
  }

  // ============================================================
  // Tuile octogonale avec valeurs en bas-centre
  // ============================================================
  Widget _buildLetterTile(String letter, double size) {
    final point = letterPoints[letter.toUpperCase()] ?? 0;
    final isJoker = letter == '_' || letter == '?';

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RackTilePainter(
          color: Colors.white,
          borderColor: Colors.black54,
          borderWidth: 1.5,
          letter: letter,
          letterSize: size * 0.55,
          letterColor: Colors.black,
          point: isJoker ? 0 : point,
          pointSize: size * 0.20,
          showJokerIndicator: isJoker,
        ),
      ),
    );
  }
}

// ============================================================
// Painter pour les tuiles octogonales du rack
// ============================================================
class _RackTilePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final String letter;
  final double letterSize;
  final Color letterColor;
  final int point;
  final double pointSize;
  final bool showJokerIndicator;

  const _RackTilePainter({
    required this.color,
    required this.borderColor,
    required this.borderWidth,
    required this.letter,
    required this.letterSize,
    required this.letterColor,
    required this.point,
    required this.pointSize,
    required this.showJokerIndicator,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fond de la tuile (octogone)
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

    // Lettre
    final displayLetter = showJokerIndicator ? '?' : letter;
    final textPainter = TextPainter(
      text: TextSpan(
        text: displayLetter,
        style: TextStyle(
          fontSize: letterSize,
          fontWeight: FontWeight.bold,
          color: letterColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Centrer la lettre
    canvas.save();
    canvas.translate(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2 - size.height * 0.08,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Points en bas-centre
    if (point > 0) {
      final pointPainter = TextPainter(
        text: TextSpan(
          text: '$point',
          style: TextStyle(
            fontSize: pointSize,
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(
        (size.width - pointPainter.width) / 2, // Centré horizontalement
        size.height - pointPainter.height - size.height * 0.06, // En bas
      );
      pointPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Indicateur Joker (petite étoile en haut à gauche)
    if (showJokerIndicator) {
      final jokerPainter = TextPainter(
        text: const TextSpan(
          text: '★',
          style: TextStyle(fontSize: 12, color: Colors.orange),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(size.width * 0.05, size.height * 0.02);
      jokerPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RackTilePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.letter != letter ||
        oldDelegate.point != point;
  }
}

// ============================================================
// Fonction pour créer un chemin octogonal
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
