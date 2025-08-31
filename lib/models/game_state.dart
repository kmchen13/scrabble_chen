import 'package:hive/hive.dart';
import 'dart:convert';
import 'placed_letter.dart';
import 'bag.dart';

part 'game_state.g.dart'; // Fichier généré par Hive

@HiveType(typeId: 0) // Assurez-vous que ce typeId est unique
class GameState {
  @HiveField(0)
  bool isLeft;

  @HiveField(1)
  final String leftName;

  @HiveField(2)
  final String leftIP;

  @HiveField(3)
  final int leftPort;

  @HiveField(4)
  final String rightName;

  @HiveField(5)
  final String rightIP;

  @HiveField(6)
  final int rightPort;

  @HiveField(7)
  List<List<String>> board;

  @HiveField(8)
  BagModel bag;

  @HiveField(9)
  List<String> leftLetters;

  @HiveField(10)
  List<String> rightLetters;

  @HiveField(11)
  int leftScore;

  @HiveField(12)
  int rightScore;

  @HiveField(13)
  List<PlacedLetter> lettersPlacedThisTurn;

  GameState({
    required this.isLeft,
    required this.leftName,
    required this.leftIP,
    required this.leftPort,
    required this.rightName,
    required this.rightIP,
    required this.rightPort,
    required this.board,
    required this.bag,
    required this.leftLetters,
    required this.rightLetters,
    required this.leftScore,
    required this.rightScore,
    required this.lettersPlacedThisTurn,
  });

  /// Réinitialise les lettres posées ce tour
  void resetPlacedThisTurn() {
    lettersPlacedThisTurn.clear();
  }

  /// Méthode pour convertir en Map (optionnel, si vous voulez garder la compatibilité JSON)
  Map<String, dynamic> toMap() {
    return {
      'isLeft': isLeft,
      'leftName': leftName,
      'leftIP': leftIP,
      'leftPort': leftPort,
      'rightName': rightName,
      'rightIP': rightIP,
      'rightPort': rightPort,
      'board': board,
      'bag': bag.toMap(),
      'leftLetters': leftLetters,
      'rightLetters': rightLetters,
      'leftScore': leftScore,
      'rightScore': rightScore,
      'lettersPlacedThisTurn':
          lettersPlacedThisTurn
              .map(
                (e) => {
                  'row': e.row,
                  'col': e.col,
                  'letter': e.letter,
                  'placedThisTurn': e.placedThisTurn,
                },
              )
              .toList(),
    };
  }

  /// Méthode pour créer un GameState à partir d'une Map (optionnel)
  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      isLeft: map['isLeft'],
      leftName: map['leftName'],
      leftIP: map['leftIP'],
      leftPort: map['leftPort'],
      rightName: map['rightName'],
      rightIP: map['rightIP'],
      rightPort: map['rightPort'],
      board: List<List<String>>.from(
        map['board'].map<List<String>>((row) => List<String>.from(row)),
      ),
      bag: BagModel.fromMap(map['bag']),
      leftLetters: List<String>.from(map['leftLetters']),
      rightLetters: List<String>.from(map['rightLetters']),
      leftScore: map['leftScore'],
      rightScore: map['rightScore'],
      lettersPlacedThisTurn:
          (map['lettersPlacedThisTurn'] as List<dynamic>)
              .map(
                (e) => PlacedLetter(
                  row: e['row'] as int,
                  col: e['col'] as int,
                  letter: e['letter'] as String,
                  placedThisTurn: e['placedThisTurn'] as bool? ?? false,
                ),
              )
          .toList(),
    );
  }

  /// Méthode pour convertir en JSON (optionnel)
  String toJson() => jsonEncode(toMap());

  /// Méthode pour créer un GameState à partir d'un JSON (optionnel)
  factory GameState.fromJson(String source) => GameState.fromMap(jsonDecode(source));

  /// Méthode pour créer une copie modifiée
  GameState copyWith({
    bool? isLeft,
    List<List<String>>? board,
    BagModel? bag,
    List<String>? leftLetters,
    List<String>? rightLetters,
    int? leftScore,
    int? rightScore,
    List<PlacedLetter>? lettersPlacedThisTurn,
  }) {
    return GameState(
      isLeft: isLeft ?? this.isLeft,
      leftName: leftName,
      leftIP: leftIP,
      leftPort: leftPort,
      rightName: rightName,
      rightIP: rightIP,
      rightPort: rightPort,
      board: board ?? this.board,
      bag: bag ?? this.bag,
      leftLetters: leftLetters ?? this.leftLetters,
      rightLetters: rightLetters ?? this.rightLetters,
      leftScore: leftScore ?? this.leftScore,
      rightScore: rightScore ?? this.rightScore,
      lettersPlacedThisTurn: lettersPlacedThisTurn ?? this.lettersPlacedThisTurn,
    );
  }

  /// Méthode pour copier depuis un autre GameState
  void copyFrom(GameState other) {
    isLeft = other.isLeft;
    leftScore = other.leftScore;
    rightScore = other.rightScore;
    leftLetters = List<String>.from(other.leftLetters);
    rightLetters = List<String>.from(other.rightLetters);
    board = other.board.map((row) => List<String>.from(row)).toList();
    bag.copyFrom(other.bag);
    lettersPlacedThisTurn = List.from(other.lettersPlacedThisTurn);
  }
}
