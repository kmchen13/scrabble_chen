import 'dart:math';

class BagModel {
  List<String> _bag = [];
  late int totalTiles = 0; // 🔹 Nombre total de jetons au début du jeu

  BagModel() {
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
    // 🔹 Calcule une seule fois le total initial
    totalTiles = _bag.length;
  }

  /// Constructeur depuis un Map<String, dynamic> ou Map<String, int>
  factory BagModel.fromMap(Map<String, dynamic> map) {
    final bag = BagModel._empty();
    map.forEach((key, value) {
      final letter = key.toString();
      final count = value is int ? value : int.tryParse(value.toString()) ?? 0;
      bag._bag.addAll(List.filled(count, letter));
    });
    return bag;
  }

  /// Constructeur vide privé
  BagModel._empty() {
    totalTiles = 102; // ✅ valeur par défaut constante (Scrabble FR)
  }

  /// Sérialisation
  Map<String, int> toMap() {
    final Map<String, int> countMap = {};
    for (final letter in _bag) {
      countMap[letter] = (countMap[letter] ?? 0) + 1;
    }
    return countMap;
  }

  /// Clone depuis un autre BagModel
  void copyFrom(BagModel other) {
    _bag = List<String>.from(other._bag);
  }

  /// Tire [count] lettres
  List<String> drawLetters(int count) {
    final random = Random();
    final drawn = <String>[];

    for (int i = 0; i < count && _bag.isNotEmpty; i++) {
      final index = random.nextInt(_bag.length);
      drawn.add(_bag.removeAt(index));
    }

    return drawn;
  }

  /// Lettres restantes
  Map<String, int> get remainingLetters => toMap();

  int get remainingCount => _bag.length;

  void clear() => _bag = [];

  void addAll(Map<String, int> newBag) {
    newBag.forEach((letter, count) {
      _bag.addAll(List.filled(count, letter));
    });
  }

  /// ✅ Ajoute une lettre au sac
  void addLetter(String letter) {
    _bag.add(letter);
  }

  /// ✅ Supprime une lettre du sac (une occurrence seulement)
  /// Retourne true si la lettre a été retirée, false sinon
  bool removeLetter(String letter) {
    final index = _bag.indexOf(letter);
    if (index != -1) {
      _bag.removeAt(index);
      return true;
    }
    return false;
  }

  /// 🔹 Sérialisation complète
  Map<String, dynamic> toJson() {
    return {'bag': _bag, 'totalTiles': totalTiles};
  }

  /// 🔹 Désérialisation complète
  factory BagModel.fromJson(Map<String, dynamic> json) {
    BagModel model = BagModel._empty();
    model._bag = List<String>.from(json['bag']);
    model.totalTiles = json['totalTiles'];
    return model;
  }
}
