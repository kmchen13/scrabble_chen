// turn_pass.dart
import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/bag.dart';

class TurnPassDialog extends StatefulWidget {
  final List<String> playerLetters;
  final BagModel bag;
  final Function(List<String>) onPass;

  const TurnPassDialog({
    Key? key,
    required this.playerLetters,
    required this.bag,
    required this.onPass,
  }) : super(key: key);

  @override
  State<TurnPassDialog> createState() => _TurnPassDialogState();
}

class _TurnPassDialogState extends State<TurnPassDialog> {
  late List<String> _playerLetters;
  List<String> _lettersToRemove = [];

  @override
  void initState() {
    super.initState();
    _playerLetters = List.from(widget.playerLetters);
  }

  void _toggleLetter(String letter, int index) {
    setState(() {
      final letterKey = '$letter-$index';
      if (_lettersToRemove.contains(letterKey)) {
        _lettersToRemove.remove(letterKey);
      } else {
        // Vérifier s'il y a assez de lettres dans le sac
        if (widget.bag.remainingCount >= _lettersToRemove.length + 1) {
          _lettersToRemove.add(letterKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plus assez de lettres dans le sac'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  void _handleCancel() {
    if (_lettersToRemove.isEmpty) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _lettersToRemove.removeLast();
      });
    }
  }

  void _handlePass() {
    // Récupérer les lettres à retirer avec leurs indices
    final lettersToRemove = <String>[];
    final indicesToRemove = <int>[];

    for (final key in _lettersToRemove) {
      final parts = key.split('-');
      lettersToRemove.add(parts[0]);
      indicesToRemove.add(int.parse(parts[1]));
    }

    // Trier les indices en ordre décroissant pour supprimer sans problème
    indicesToRemove.sort((a, b) => b.compareTo(a));

    // Supprimer les lettres du rack
    for (final index in indicesToRemove) {
      _playerLetters.removeAt(index);
    }

    // Tirer de nouvelles lettres du sac
    final newLetters = widget.bag.drawLetters(lettersToRemove.length);

    // Ajouter les nouvelles lettres au rack
    _playerLetters.addAll(newLetters);

    // Remettre les lettres retirées dans le sac
    for (final letter in lettersToRemove) {
      widget.bag.addLetter(letter);
    }

    // Fermer le dialogue et retourner les nouvelles lettres
    Navigator.of(context).pop();
    widget.onPass(_playerLetters);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Text(
              'Passer son tour',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2A3A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Cliquez sur les lettres que vous souhaitez changer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),

            // Rack du joueur
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: List.generate(_playerLetters.length, (index) {
                  final letter = _playerLetters[index];
                  if (letter.isEmpty) return const SizedBox.shrink();

                  final letterKey = '$letter-$index';
                  final isSelected = _lettersToRemove.contains(letterKey);

                  return GestureDetector(
                    onTap: () => _toggleLetter(letter, index),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.blue.withOpacity(0.3)
                                : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color:
                              isSelected ? Colors.blue : Colors.grey.shade400,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow:
                            isSelected
                                ? [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                                : [],
                      ),
                      child: Center(
                        child: Text(
                          letter.toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.blue : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // Indicateur du nombre de lettres à changer
            Text(
              _lettersToRemove.isEmpty
                  ? 'Aucune lettre sélectionnée'
                  : '${_lettersToRemove.length} lettre${_lettersToRemove.length > 1 ? 's' : ''} à changer',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color:
                    _lettersToRemove.isEmpty
                        ? Colors.grey.shade500
                        : Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 20),

            // Boutons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Bouton Annuler
                Expanded(
                  child: OutlinedButton(
                    onPressed: _handleCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      _lettersToRemove.isEmpty ? 'Fermer' : 'Annuler',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Bouton Passer
                Expanded(
                  child: ElevatedButton(
                    onPressed: _lettersToRemove.isEmpty ? null : _handlePass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2A3A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
