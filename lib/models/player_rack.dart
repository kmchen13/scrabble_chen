import 'package:flutter/material.dart';
import '../models/dragged_letter.dart';

class PlayerRack extends StatelessWidget {
  final List<String> letters;
  final void Function(int fromIndex, int toIndex)? onMove;
  final void Function(int index)? onRemoveLetter;
  final void Function(String letter)?
  onAddLetter; // ✅ Nouveau callback pour retour depuis le board

  const PlayerRack({
    super.key,
    required this.letters,
    this.onMove,
    this.onRemoveLetter,
    this.onAddLetter, // ✅ Ajouté
  });

  @override
  Widget build(BuildContext context) {
    final tileSize = _calculateTileSize(context);

    return DragTarget<DraggedLetter>(
      onWillAccept: (data) => true, // Accepte toujours
      onAccept: (data) {
        if (onAddLetter != null) {
          onAddLetter!(data.letter); // ✅ Retour au rack
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: tileSize + 16,
          alignment: Alignment.centerLeft,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: letters.length,
            itemBuilder: (context, index) {
              return Draggable<DraggedLetter>(
                data: DraggedLetter(letter: letters[index], fromIndex: index),
                feedback: Material(
                  color: Colors.transparent,
                  child: _buildLetterTile(letters[index], tileSize),
                ),
                childWhenDragging: _buildLetterTile("", tileSize),
                child: GestureDetector(
                  onLongPress: () => onRemoveLetter?.call(index),
                  child: _buildLetterTile(letters[index], tileSize),
                ),
              );
            },
          ),
        );
      },
    );
  }

  double _calculateTileSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final rackWidth = screenWidth * 0.9;
    final tileSize = rackWidth / 8;
    return tileSize.clamp(30, 50);
  }

  Widget _buildLetterTile(String letter, double size) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: letter.isNotEmpty ? Colors.amber[200] : Colors.grey[300],
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(fontSize: size * 0.6, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
