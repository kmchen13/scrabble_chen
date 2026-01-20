import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';

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

    final rackWidth = rackSlots * tileSize + rackSlots * 4; // marges incluses

    return SizedBox(
      height: tileSize + 16,
      child: Center(
        child: Stack(
          children: [
            // 🟨 Rack VISUEL (7 tuiles, parfaitement centré)
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

            // 🫥 Zone INVISIBLE pour drop après la dernière tuile
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
    return size.clamp(36, 56);
  }

  Widget _buildLetterTile(String letter, double size) {
    final point = letterPoints[letter.toUpperCase()] ?? 0;

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF5DEB3),
          border: Border.all(color: Colors.black, width: 1.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Positioned(
              bottom: 1,
              right: 1,
              child: Text(
                '$point',
                style: TextStyle(
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
