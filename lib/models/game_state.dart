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
  String leftName;

  @HiveField(2)
  String leftIP;

  @HiveField(3)
  int leftPort;

  @HiveField(4)
  String rightName;

  @HiveField(5)
  String rightIP;

  @HiveField(6)
  int rightPort;

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

  @HiveField(14)
  final String gameId; // <--- Nouveau champ

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
    required this.gameId, // <--- obligatoire
  });

  @override
  int get hashCode {
    return Object.hash(leftScore, rightScore);
  }

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
      'board': board.map((row) => row.toList()).toList(),
      'bag': bag.toMap(),
      'leftLetters': leftLetters.toList(),
      'rightLetters': rightLetters.toList(),
      'leftScore': leftScore,
      'rightScore': rightScore,

      'lettersPlacedThisTurn':
          lettersPlacedThisTurn.map((e) => e.toMap()).toList(),
      'gameId': gameId, // <--- sérialisation
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      isLeft: map['isLeft'] as bool,
      leftName: map['leftName'] as String,
      leftIP: map['leftIP'] as String,
      leftPort: map['leftPort'] as int,
      rightName: map['rightName'] as String,
      rightIP: map['rightIP'] as String,
      rightPort: map['rightPort'] as int,
      board:
          (map['board'] as List).map((row) => List<String>.from(row)).toList(),
      bag: BagModel.fromMap(Map<String, dynamic>.from(map['bag'])),
      leftLetters: List<String>.from(map['leftLetters']),
      rightLetters: List<String>.from(map['rightLetters']),
      leftScore: map['leftScore'] as int,
      rightScore: map['rightScore'] as int,
      lettersPlacedThisTurn:
          (map['lettersPlacedThisTurn'] as List<dynamic>? ?? [])
              .map(
                (e) => PlacedLetter.fromMap(e),
              ) // ici isJoker sera lu correctement
              .toList(),
      gameId: map['gameId'] as String, // <--- désérialisation
    );
  }

  /// Méthode pour convertir en JSON (optionnel)
  String toJson() => jsonEncode(toMap());

  /// Méthode pour créer un GameState à partir d'un JSON (optionnel)
  factory GameState.fromJson(String source) =>
      GameState.fromMap(jsonDecode(source));

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
    String? gameId,
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
      lettersPlacedThisTurn:
          lettersPlacedThisTurn ?? this.lettersPlacedThisTurn,
      gameId: gameId ?? this.gameId, // <--- copie du gameId
    );
  }

  /// Méthode pour copier depuis un autre GameState
  void copyFrom(GameState other) {
    // 🔥 IDENTITÉ DE LA PARTIE
    leftName = other.leftName;
    rightName = other.rightName;

    // 🔥 LOGIQUE DE JEU
    isLeft = other.isLeft;
    leftScore = other.leftScore;
    rightScore = other.rightScore;

    // 🔥 CONTENU
    leftLetters = List<String>.from(other.leftLetters);
    rightLetters = List<String>.from(other.rightLetters);
    board = other.board.map((row) => List<String>.from(row)).toList();
    bag = BagModel.fromJson(other.bag.toJson());
    lettersPlacedThisTurn = List.from(other.lettersPlacedThisTurn);
  }

  bool isMyTurn(myName) {
    if (this.isLeft && this.leftName == myName ||
        !this.isLeft && this.rightName == myName)
      return true;
    else
      return false;
  }

  String partnerFrom(String userName) {
    return leftName == userName ? rightName : leftName;
  }
}

extension GameStateRack on GameState {
  /// Retourne les lettres du joueur local
  List<String> localRack(String localUserName) {
    if (leftName == localUserName) {
      return List<String>.from(leftLetters);
    } else {
      return List<String>.from(rightLetters);
    }
  }
}
