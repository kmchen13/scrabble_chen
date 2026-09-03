import 'dart:math';

class BagModel {
  List<String> _bag = [];
  late int
  totalTiles; // 🔹 Nombre total de jetons au début du jeu (valeur immuable en pratique)

  // ─── Constructeur principal (création d’un nouveau jeu) ───
  BagModel() : totalTiles = 0 {
    final Map<String, int> letterDistribution = {
      'A': 9, 'B': 2, 'C': 2, 'D': 3, 'E': 15, 'F': 2,
      'G': 2, 'H': 2, 'I': 8, 'J': 1, 'K': 1, 'L': 5,
      'M': 3, 'N': 6, 'O': 6, 'P': 2, 'Q': 1, 'R': 6,
      'S': 6, 'T': 6, 'U': 6, 'V': 2, 'W': 1, 'X': 1,
      'Y': 1, 'Z': 1, ' ': 2, // jokers
    };

    letterDistribution.forEach((letter, count) {
      _bag.addAll(List.filled(count, letter));
    });
    // 🔹 On stocke une fois pour toutes le total initial
    totalTiles = _bag.length;
  }

  // ─── Constructeur privé utilisé par les factories ───
  // Il initialise totalTiles à 0 (valeur par défaut), mais sera
  // écrasé immédiatement après par la factory appelante.
  BagModel._empty() : totalTiles = 0;

  // ─── Reconstruction depuis un Map de comptes (ex: {'A':5, 'B':2}) ───
  // ⚠️ Le total initial doit être fourni explicitement (il n’est pas contenu dans le Map).
  factory BagModel.fromMap(
    Map<String, dynamic> map, {
    required int initialTotal,
  }) {
    final bag = BagModel._empty();
    map.forEach((key, value) {
      final letter = key.toString();
      final count = value is int ? value : int.tryParse(value.toString()) ?? 0;
      bag._bag.addAll(List.filled(count, letter));
    });
    // 🔹 Restauration du total initial (indispensable pour la vérification de fin de partie)
    bag.totalTiles = initialTotal;
    return bag;
  }

  // ─── Reconstruction depuis un JSON complet (utilisé par la sauvegarde) ───
  factory BagModel.fromJson(Map<String, dynamic> json) {
    final bag = BagModel._empty();
    bag._bag = List<String>.from(json['bag'] as List);
    bag.totalTiles = json['totalTiles'] as int; // déjà présent dans le JSON
    return bag;
  }

  // ─── Sérialisation simple (comptes de lettres) ───
  Map<String, int> toMap() {
    final Map<String, int> countMap = {};
    for (final letter in _bag) {
      countMap[letter] = (countMap[letter] ?? 0) + 1;
    }
    return countMap;
  }

  // ─── Sérialisation complète (inclut le total initial) ───
  Map<String, dynamic> toJson() {
    return {'bag': _bag, 'totalTiles': totalTiles};
  }

  // ─── Autres méthodes ───

  /// Clone un autre sac
  void copyFrom(BagModel other) {
    _bag = List<String>.from(other._bag);
    // On ne modifie pas totalTiles ici car c'est une valeur fixe
    // qui doit rester celle du jeu en cours.
  }

  /// Tire [count] lettres du sac
  List<String> drawLetters(int count) {
    final random = Random();
    final drawn = <String>[];

    for (int i = 0; i < count && _bag.isNotEmpty; i++) {
      final index = random.nextInt(_bag.length);
      drawn.add(_bag.removeAt(index));
    }
    return drawn;
  }

  /// Lettres restantes (comptes)
  Map<String, int> get remainingLetters => toMap();

  /// Nombre de lettres restantes dans le sac
  int get remainingCount => _bag.length;

  /// Vide le sac
  void clear() => _bag = [];

  /// Ajoute un lot de lettres (pour restauration partielle)
  void addAll(Map<String, int> newBag) {
    newBag.forEach((letter, count) {
      _bag.addAll(List.filled(count, letter));
    });
  }

  /// Ajoute une seule lettre
  void addLetter(String letter) {
    _bag.add(letter);
  }

  /// Retire une occurrence d'une lettre (si présente)
  bool removeLetter(String letter) {
    final index = _bag.indexOf(letter);
    if (index != -1) {
      _bag.removeAt(index);
      return true;
    }
    return false;
  }
}
