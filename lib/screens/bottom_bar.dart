import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  final bool canUndo;
  final bool canSubmit;
  final VoidCallback onUndo;
  final VoidCallback onSubmit;
  final VoidCallback onShowBag;
  final VoidCallback onQuit;

  const BottomBar({
    super.key,
    required this.canUndo,
    required this.canSubmit,
    required this.onUndo,
    required this.onSubmit,
    required this.onShowBag,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            tooltip: "Annuler",
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? onUndo : null,
          ),
          IconButton(
            tooltip: "Envoyer",
            icon: const Icon(Icons.send),
            onPressed: canSubmit ? onSubmit : null,
          ),
          IconButton(
            tooltip: "Sac",
            icon: const Icon(Icons.work),
            onPressed: onShowBag,
          ),
          IconButton(
            tooltip: "Quitter",
            icon: const Icon(Icons.exit_to_app),
            onPressed: onQuit,
          ),
        ],
      ),
    );
  }
}
