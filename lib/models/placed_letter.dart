class PlacedLetter {
  final int row;
  final int col;
  final String letter; //' 'pour un joker
  final String? jokerValue;

  final bool placedThisTurn;

  const PlacedLetter({
    required this.row,
    required this.col,
    required this.letter,
    this.jokerValue,
    required this.placedThisTurn,
  });

  bool get isJoker => letter == ' ';

  String get displayLetter => jokerValue ?? letter;

  factory PlacedLetter.fromMap(Map<String, dynamic> map) {
    return PlacedLetter(
      row: map['row'] ?? 0,
      col: map['col'] ?? 0,
      letter: map['letter'] ?? '',
      jokerValue: map['jokerValue'], // peut rester nullable
      placedThisTurn: map['placedThisTurn'] ?? false, // ✅ valeur par défaut
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'row': row,
      'col': col,
      'letter': letter,
      'isJoker': isJoker,
      'jokerValue': jokerValue,
      'placedThisTurn': placedThisTurn,
    };
  }
}

extension PlacedLetterCopy on PlacedLetter {
  PlacedLetter copyWith({
    int? row,
    int? col,
    String? letter,
    bool? isJoker,
    String? jokerValue,
    bool? placedThisTurn,
  }) {
    return PlacedLetter(
      row: row ?? this.row,
      col: col ?? this.col,
      letter: letter ?? this.letter,
      jokerValue:
          isJoker == true
              ? (jokerValue ?? this.jokerValue)
              : (isJoker == false ? null : this.jokerValue),
      placedThisTurn: placedThisTurn ?? this.placedThisTurn,
    );
  }
}
