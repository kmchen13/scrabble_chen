import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dragged_letter.dart';

class PlayerRack extends StatelessWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter)? onAddLetter;

  const PlayerRack({
    super.key,
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
  });

  @override
  Widget build(BuildContext context) {
    return _PlayerRackInternal(
      letters: letters,
      onMove: onMove,
      onRemoveLetter: onRemoveLetter,
      onAddLetter: onAddLetter,
    );
  }
}

class _PlayerRackInternal extends StatefulWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter)? onAddLetter;

  const _PlayerRackInternal({
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter,
  });

  @override
  State<_PlayerRackInternal> createState() => _PlayerRackInternalState();
}

class _PlayerRackInternalState extends State<_PlayerRackInternal> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final tileSize = _calculateTileSize(context);

    return Container(
      height: tileSize + 16,
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: widget.letters.length + 1, // +1 pour emplacement fin
        itemBuilder: (context, index) {
          return DragTarget<DraggedLetter>(
            onWillAccept: (data) {
              setState(() => _hoveredIndex = index);
              return true;
            },
            onLeave: (_) {
              setState(() => _hoveredIndex = null);
            },
            onAccept: (data) {
              setState(() => _hoveredIndex = null);
              if (widget.onMove != null && data.fromIndex > 0) {
                widget.onMove!(data.fromIndex, index);
              }
            },
            builder: (context, candidateData, rejectedData) {
              if (_hoveredIndex == index) {
                return _buildPlaceholderTile(tileSize);
              }
              if (index < widget.letters.length) {
                final letter = widget.letters[index];
                return Draggable<DraggedLetter>(
                  data: DraggedLetter(letter: letter, fromIndex: index),
                  onDragStarted: () {
                    HapticFeedback.mediumImpact();
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
                  child: _buildLetterTile(letter, tileSize),
                );
              }
              return SizedBox(width: tileSize); // slot vide à la fin
            },
          );
        },
      ),
    );
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
        color: letter.isNotEmpty ? Colors.amber[200] : Colors.grey[300],
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
          if (letter.isNotEmpty)
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

  Widget _buildPlaceholderTile(double size) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(4),
        color: Colors.transparent,
      ),
    );
  }
}
