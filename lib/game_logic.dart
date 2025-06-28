import 'dart:math';

List<String> drawLetters(List<String> bag, int count) {
  final random = Random();
  final List<String> hand = [];

  for (int i = 0; i < count && bag.isNotEmpty; i++) {
    int index = random.nextInt(bag.length);
    hand.add(bag.removeAt(index));
  }

  return hand;
}
