// game_state.dart
import 'package:hive/hive.dart';
import 'dart:convert';
import 'placed_letter.dart';
import 'bag.dart';

part 'game_state.g.dart';

@HiveType(typeId: 0)
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
  final String gameId;

  @HiveField(15)
  List<List<Map<String, dynamic>?>> boardJokerInfo;

  // ============================================================
  // NOUVELLES VARIABLES : Nombre d'étoiles restantes par joueur
  // ============================================================
  @HiveField(16)
  int leftStars;

  @HiveField(17)
  int rightStars;

  // ============================================================
  // Constructeur modifié avec valeurs par défaut pour les étoiles
  // ============================================================
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
    required this.gameId,
    List<List<Map<String, dynamic>?>>? boardJokerInfo,
    this.leftStars = 0, // Valeur par défaut : 3 étoiles par joueur
    this.rightStars = 0, // Valeur par défaut : 3 étoiles par joueur
  }) : boardJokerInfo =
           boardJokerInfo ??
           List.generate(
             15,
             (_) => List<Map<String, dynamic>?>.filled(15, null),
           );

  @override
  int get hashCode {
    return Object.hash(leftScore, rightScore);
  }

  void resetPlacedThisTurn() {
    lettersPlacedThisTurn.clear();
  }

  // ============================================================
  // Méthodes utilitaires pour les étoiles
  // ============================================================

  /// Vérifie si le joueur gauche a encore des étoiles disponibles
  bool get hasLeftStar => leftStars > 0;

  /// Vérifie si le joueur droit a encore des étoiles disponibles
  bool get hasRightStar => rightStars > 0;

  /// Utilise une étoile pour le joueur gauche (retourne true si réussi)
  bool useLeftStar() {
    if (leftStars <= 0) return false;
    leftStars--;
    return true;
  }

  /// Utilise une étoile pour le joueur droit (retourne true si réussi)
  bool useRightStar() {
    if (rightStars <= 0) return false;
    rightStars--;
    return true;
  }

  /// Utilise une étoile pour un joueur donné
  bool useStarForPlayer(String userName) {
    if (leftName == userName) {
      return useLeftStar();
    } else if (rightName == userName) {
      return useRightStar();
    }
    return false;
  }

  /// Vérifie si un joueur a encore des étoiles
  bool hasStarForPlayer(String userName) {
    if (leftName == userName) {
      return hasLeftStar;
    } else if (rightName == userName) {
      return hasRightStar;
    }
    return false;
  }

  /// Récupère le nombre d'étoiles restantes pour un joueur
  int getStarsForPlayer(String userName) {
    if (leftName == userName) {
      return leftStars;
    } else if (rightName == userName) {
      return rightStars;
    }
    return 0;
  }

  /// Réinitialise les étoiles en fin de partie
  void resetStars({int starsPerPlayer = 3}) {
    leftStars = starsPerPlayer;
    rightStars = starsPerPlayer;
  }

  // ============================================================
  // toMap modifié
  // ============================================================
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
      'boardJokerInfo':
          boardJokerInfo
              .map((row) => row.map((e) => e?.cast<String, dynamic>()).toList())
              .toList(),
      'bag': bag.toMap(),
      'leftLetters': leftLetters.toList(),
      'rightLetters': rightLetters.toList(),
      'leftScore': leftScore,
      'rightScore': rightScore,
      'lettersPlacedThisTurn':
          lettersPlacedThisTurn.map((e) => e.toMap()).toList(),
      'gameId': gameId,
      // NOUVEAUX CHAMPS
      'leftStars': leftStars,
      'rightStars': rightStars,
    };
  }

  // ============================================================
  // fromMap modifié
  // ============================================================
  factory GameState.fromMap(Map<String, dynamic> map) {
    // Gérer boardJokerInfo
    List<List<Map<String, dynamic>?>> boardJokerInfoData;

    if (map['boardJokerInfo'] != null) {
      final rawData = map['boardJokerInfo'] as List;
      boardJokerInfoData =
          rawData
              .map(
                (row) =>
                    (row as List)
                        .map(
                          (e) =>
                              e != null ? Map<String, dynamic>.from(e) : null,
                        )
                        .toList(),
              )
              .toList();
    } else {
      boardJokerInfoData = List.generate(
        15,
        (_) => List<Map<String, dynamic>?>.filled(15, null),
      );
    }

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
      boardJokerInfo: boardJokerInfoData,
      bag: BagModel.fromMap(Map<String, dynamic>.from(map['bag'])),
      leftLetters: List<String>.from(map['leftLetters']),
      rightLetters: List<String>.from(map['rightLetters']),
      leftScore: map['leftScore'] as int,
      rightScore: map['rightScore'] as int,
      lettersPlacedThisTurn:
          (map['lettersPlacedThisTurn'] as List<dynamic>? ?? [])
              .map((e) => PlacedLetter.fromMap(e))
              .toList(),
      gameId: map['gameId'] as String,
      // NOUVEAUX CHAMPS AVEC VALEURS PAR DÉFAUT SI ABSENTS
      leftStars: map['leftStars'] as int? ?? 3,
      rightStars: map['rightStars'] as int? ?? 3,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameState.fromJson(String source) =>
      GameState.fromMap(jsonDecode(source));

  // ============================================================
  // copyWith modifié
  // ============================================================
  GameState copyWith({
    bool? isLeft,
    List<List<String>>? board,
    List<List<Map<String, dynamic>?>>? boardJokerInfo,
    BagModel? bag,
    List<String>? leftLetters,
    List<String>? rightLetters,
    int? leftScore,
    int? rightScore,
    List<PlacedLetter>? lettersPlacedThisTurn,
    String? gameId,
    int? leftStars,
    int? rightStars,
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
      boardJokerInfo: boardJokerInfo ?? this.boardJokerInfo,
      bag: bag ?? this.bag,
      leftLetters: leftLetters ?? this.leftLetters,
      rightLetters: rightLetters ?? this.rightLetters,
      leftScore: leftScore ?? this.leftScore,
      rightScore: rightScore ?? this.rightScore,
      lettersPlacedThisTurn:
          lettersPlacedThisTurn ?? this.lettersPlacedThisTurn,
      gameId: gameId ?? this.gameId,
      leftStars: leftStars ?? this.leftStars,
      rightStars: rightStars ?? this.rightStars,
    );
  }

  // ============================================================
  // copyFrom modifié
  // ============================================================
  void copyFrom(GameState other) {
    leftName = other.leftName;
    rightName = other.rightName;
    isLeft = other.isLeft;
    leftScore = other.leftScore;
    rightScore = other.rightScore;
    leftLetters = List<String>.from(other.leftLetters);
    rightLetters = List<String>.from(other.rightLetters);
    board = other.board.map((row) => List<String>.from(row)).toList();
    boardJokerInfo =
        other.boardJokerInfo
            .map(
              (row) =>
                  row
                      .map(
                        (e) => e != null ? Map<String, dynamic>.from(e) : null,
                      )
                      .toList(),
            )
            .toList();
    bag = BagModel.fromJson(other.bag.toJson());
    lettersPlacedThisTurn = List.from(other.lettersPlacedThisTurn);
    // NOUVEAUX CHAMPS
    leftStars = other.leftStars;
    rightStars = other.rightStars;
  }

  bool isMyTurn(myName) {
    if (this.isLeft && this.leftName == myName ||
        !this.isLeft && this.rightName == myName)
      return true;
    else
      return false;
  }

  String partnerFrom(String user) {
    return leftName == user ? rightName : leftName;
  }
}

// ============================================================
// Extension Rack (inchangée)
// ============================================================
extension GameStateRack on GameState {
  List<String> localRack(String localUserName) {
    if (leftName == localUserName) {
      return List<String>.from(leftLetters);
    } else {
      return List<String>.from(rightLetters);
    }
  }
}
