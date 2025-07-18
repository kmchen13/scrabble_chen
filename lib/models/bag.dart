import 'dart:math';

class BagModel {
  List<String> _bag = [];

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
  }

  /// Constructeur depuis un Map
  BagModel.fromMap(Map<String, int> map) {
    _bag = [];
    map.forEach((letter, count) {
      _bag.addAll(List.filled(count, letter));
    });
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
}
