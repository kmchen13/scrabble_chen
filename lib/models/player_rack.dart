import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrabble_P2P/models/dragged_letter.dart';

class PlayerRack extends StatelessWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter, {int? hoveredIndex})?
  onAddLetter; // Utilisez un paramètre nommé

  final void Function(int row, int col)?
  onRemoveFromBoard; // Ajoutez cette ligne

  const PlayerRack({
    Key? key,
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
    this.onRemoveFromBoard, // Initialisez-le ici
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
  final void Function(String letter, {int? hoveredIndex})?
  onAddLetter; // Utilisez un paramètre nommé

  final void Function(int row, int col)? onRemoveFromBoard;

  const _PlayerRackInternal({
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
    this.onRemoveFromBoard, // Initialisez-le ici
  });

  @override
  State<_PlayerRackInternal> createState() => _PlayerRackInternalState();
}

class _PlayerRackInternalState extends State<_PlayerRackInternal> {
  int? _hoveredIndex;
  DraggedLetter? _dragging;

  @override
  Widget build(BuildContext context) {
    final tileSize = _calculateTileSize(context);

    // si on survole, on construit une version temporaire du rack réordonné
    final previewLetters = _computePreviewLetters();

    return Container(
      height: tileSize + 16,
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: previewLetters.length + 1,
        itemBuilder: (context, index) {
          if (index < previewLetters.length) {
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

                // Cas 1 : la lettre vient du rack
                if (data.fromIndex >= 0) {
                  if (widget.onMove != null) {
                    widget.onMove!(data.fromIndex, index);
                  }
                }
                // Cas 2 : la lettre vient du board
                else if (data.fromIndex == -1) {
                  if (widget.onAddLetter != null) {
                    widget.onAddLetter?.call(
                      data.letter,
                      hoveredIndex: _hoveredIndex,
                    ); // Utilisez un paramètre nommé
                  }
                  // Signaler au board qu’on retire la lettre
                  if (widget.onRemoveFromBoard != null &&
                      data.row != null &&
                      data.col != null) {
                    widget.onRemoveFromBoard!(data.row!, data.col!);
                  }
                }
              },
              builder: (context, candidateData, rejectedData) {
                return Draggable<DraggedLetter>(
                  data: DraggedLetter(letter: letter, fromIndex: index),
                  onDragStarted: () => HapticFeedback.mediumImpact(),
                  onDragEnd: (details) {
                    // Si le drop n’a pas été accepté, on remet la tuile dans le rack
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
          } else {
            // slot vide à la fin
            return SizedBox(width: tileSize);
          }
        },
      ),
    );
  }

  /// Construit une version temporaire des lettres avec décalage
  List<String> _computePreviewLetters() {
    if (_hoveredIndex == null || _dragging == null) {
      return List.of(widget.letters);
    }

    final preview = List.of(widget.letters);
    final fromIndex = _dragging!.fromIndex;

    // on déclare dragged une seule fois
    late String dragged;

    if (fromIndex >= 0 && fromIndex < preview.length) {
      dragged = preview.removeAt(fromIndex);
    } else {
      // la lettre venait du plateau → on ne retire rien du rack
      dragged = _dragging!.letter;
    }

    // insérer la lettre déplacée à l’index survolé
    final targetIndex = _hoveredIndex!.clamp(0, preview.length);
    preview.insert(targetIndex, dragged);

    return preview;
  }

  double _calculateTileSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rackWidth = screenWidth * 0.9;
    final tileSize = rackWidth / 8;
    return tileSize.clamp(30, 50);
  }

  Widget _buildLetterTile(String letter, double size) {
    final point = letterPoints[letter.toUpperCase()] ?? 0;
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.amber[200],
        border: Border.all(color: Colors.black),
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
              ),
            ),
          ),
          Positioned(
            bottom: 2,
            right: 4,
            child: Text(
              '$point',
              style: TextStyle(
                fontSize: size * 0.25,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
