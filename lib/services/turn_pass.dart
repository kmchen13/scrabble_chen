import 'package:flutter/material.dart';
import 'package:scrabble_P2P/models/bag.dart';
import 'package:scrabble_P2P/screens/change_letters_dialog.dart'; // importer le nouveau fichier

class TurnPassDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeLettersDialog(
      playerLetters: playerLetters,
      bag: bag,
      title: 'Passer son tour',
      description:
          'Cliquez sur les lettres que vous souhaitez changer, puis sur "Passer" pour valider. '
          'Si aucune lettre n\'est sélectionnée, vous passerez simplement votre tour.',
      confirmText: 'Passer',
      allowEmptySelection: true,
      cancelRemovesLast: true, // pour reproduire l'ancien comportement
      onConfirm: onPass,
    );
  }
}
