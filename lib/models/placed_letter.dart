class PlacedLetter {
  final int row;
  final int col;

  /// Lettre réelle posée sur le plateau
  /// → pour un joker : '*'
  final String letter;

  /// Est-ce un joker ?
  final bool isJoker;

  /// Lettre que le joker représente (A–Z)
  /// null si ce n'est pas un joker
  final String? jokerValue;

  final bool placedThisTurn;

  const PlacedLetter({
    required this.row,
    required this.col,
    required this.letter,
    required this.isJoker,
    this.jokerValue,
    required this.placedThisTurn,
  }) : assert(
         isJoker == false || jokerValue != null,
         'Un joker doit avoir une jokerValue',
       );

  /// Lettre à afficher sur le board
  String get displayLetter => isJoker ? jokerValue! : letter;

  factory PlacedLetter.fromMap(Map<String, dynamic> map) {
    return PlacedLetter(
      row: map['row'] ?? 0,
      col: map['col'] ?? 0,
      letter: map['letter'] ?? '',
      isJoker: map['isJoker'] ?? false, // ✅ valeur par défaut
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
      isJoker: isJoker ?? this.isJoker,
      jokerValue:
          isJoker == true
              ? (jokerValue ?? this.jokerValue)
              : (isJoker == false ? null : this.jokerValue),
      placedThisTurn: placedThisTurn ?? this.placedThisTurn,
    );
  }
}
