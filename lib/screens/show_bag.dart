import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/bag.dart';

extension BagDialog on BagModel {
  void showContents(BuildContext context) {
    final remaining = this.remainingLetters;

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Lettres restantes dans le sac"),
            content: SizedBox(
              width: 200,
              height: 300,
              child: GridView.count(
                crossAxisCount: 3,
                childAspectRatio: 3.5,
                children:
                    remaining.entries
                        .map(
                          (entry) => Text(
                            "${entry.key} : ${entry.value}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Fermer"),
              ),
            ],
          ),
    );
  }
}
