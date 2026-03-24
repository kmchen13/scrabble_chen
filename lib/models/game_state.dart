/* Après toutes les modifications, n'oubliez pas de régénérer les fichiers Hive avec la commande suivante :
flutter pub run build_runner build --delete-conflicting-outputs
*/
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
  List<List<PlacedLetter?>> board;

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

      'board':
          board
              .map(
                (row) =>
                    row
                        .map((cell) => cell?.toMap()) // 🔥 IMPORTANT
                        .toList(),
              )
              .toList(),

      'bag': bag.toMap(),
      'leftLetters': leftLetters,
      'rightLetters': rightLetters,
      'leftScore': leftScore,
      'rightScore': rightScore,

      'lettersPlacedThisTurn':
          lettersPlacedThisTurn.map((e) => e.toMap()).toList(),

      'gameId': gameId,
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    return GameState(
      isLeft: map['isLeft'],
      leftName: map['leftName'],
      leftIP: map['leftIP'],
      leftPort: map['leftPort'],
      rightName: map['rightName'],
      rightIP: map['rightIP'],
      rightPort: map['rightPort'],

      board:
          (map['board'] as List)
              .map(
                (row) =>
                    (row as List)
                        .map(
                          (cell) =>
                              cell != null
                                  ? PlacedLetter.fromMap(
                                    Map<String, dynamic>.from(cell),
                                  )
                                  : null,
                        )
                        .toList(),
              )
              .toList(),

      bag: BagModel.fromMap(Map<String, dynamic>.from(map['bag'])),

      leftLetters: List<String>.from(map['leftLetters']),
      rightLetters: List<String>.from(map['rightLetters']),

      leftScore: map['leftScore'],
      rightScore: map['rightScore'],

      lettersPlacedThisTurn:
          (map['lettersPlacedThisTurn'] as List? ?? [])
              .map((e) => PlacedLetter.fromMap(Map<String, dynamic>.from(e)))
              .toList(),

      gameId: map['gameId'],
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
    List<List<PlacedLetter?>>? board,
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
      gameId: gameId ?? this.gameId,
    );
  }

  /// Méthode pour copier depuis un autre GameState
  void copyFrom(GameState other) {
    leftName = other.leftName;
    rightName = other.rightName;

    isLeft = other.isLeft;
    leftScore = other.leftScore;
    rightScore = other.rightScore;

    leftLetters = List<String>.from(other.leftLetters);
    rightLetters = List<String>.from(other.rightLetters);

    // 🔥 CORRECTION MAJEURE (joker conservé)
    board =
        other.board
            .map((row) => row.map((cell) => cell?.copyWith()).toList())
            .toList();

    bag = BagModel.fromJson(other.bag.toJson());

    lettersPlacedThisTurn =
        other.lettersPlacedThisTurn.map((e) => e.copyWith()).toList();
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
