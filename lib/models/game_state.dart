// game_state.dart
import 'package:hive/hive.dart';
import 'dart:convert';
import 'placed_letter.dart';
import 'bag.dart';

part 'game_state.g.dart';
// game_state.dart

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
    };
  }

  factory GameState.fromMap(Map<String, dynamic> map) {
    // ✅ GÉRER LE CAS OÙ boardJokerInfo EST NULL
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
      // ✅ CRÉER UN TABLEAU VIDE SI NULL
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
      boardJokerInfo: boardJokerInfoData, // ✅ UTILISER LA VALEUR GÉRÉE
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
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameState.fromJson(String source) =>
      GameState.fromMap(jsonDecode(source));

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
    );
  }

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

extension GameStateRack on GameState {
  List<String> localRack(String localUserName) {
    if (leftName == localUserName) {
      return List<String>.from(leftLetters);
    } else {
      return List<String>.from(rightLetters);
    }
  }
}
