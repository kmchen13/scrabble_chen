import 'dart:convert';

import 'bag.dart';

class GameState {
  bool isLeft;
  final String leftName;
  final String leftIP;
  final String leftPort;
  final String rightName;
  final String rightIP;
  final String rightPort;
  List<List<String>> board;
  BagModel bag;
  List<String> leftLetters;
  List<String> rightLetters;
  int leftScore;
  int rightScore;

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
  });

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
      'bag': bag.remainingLetters,
      'leftLetters': leftLetters,
      'rightLetters': rightLetters,
      'leftScore': leftScore,
      'rightScore': rightScore,
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
      board: List<List<String>>.from(
        map['board'].map<List<String>>((row) => List<String>.from(row)),
      ),
      bag: BagModel(),
      leftLetters: List<String>.from(map['leftLetters']),
      rightLetters: List<String>.from(map['rightLetters']),
      leftScore: map['leftScore'],
      rightScore: map['rightScore'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameState.fromJson(String source) =>
      GameState.fromMap(jsonDecode(source));

  GameState copyWith({
    bool? isrightTurn,
    List<List<String>>? board,
    BagModel? bag,
    List<String>? leftLetters,
    List<String>? rightLetters,
    var leftScore,
    var rightScore,
  }) {
    return GameState(
      isLeft: isLeft,
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
    );
  }

  void copyFrom(GameState other) {
    isLeft = other.isLeft;
    leftScore = other.leftScore;
    rightScore = other.rightScore;

    leftLetters = List<String>.from(other.leftLetters);
    rightLetters = List<String>.from(other.rightLetters);

    // ✅ Copie profonde du board
    board = other.board.map((row) => List<String>.from(row)).toList();

    // ✅ Copie indépendante du sac
    bag.copyFrom(other.bag);
  }
}
