import 'dart:convert';
import 'bag.dart';

class GameState {
  List<List<String>> board;
  List<String> hostLetters;
  List<String> clientLetters;
  BagModel? bag;

  int hostScore;
  int clientScore;
  bool isClientTurn;

  String hostUserName;
  String clientUserName;

  GameState({
    required this.board,
    required this.hostLetters,
    required this.clientLetters,
    this.bag,
    this.hostScore = 0,
    this.clientScore = 0,
    this.isClientTurn = false,
    required this.hostUserName,
    required this.clientUserName,
  });

  static List<List<String>> createEmptyBoard(int size) {
    return List.generate(size, (_) => List.generate(size, (_) => ''));
  }

  Map<String, dynamic> toJson() {
    return {
      'board': board,
      'hostLetters': hostLetters,
      'clientLetters': clientLetters,
      'bag': bag?.toJson(),
      'hostScore': hostScore,
      'clientScore': clientScore,
      'isClientTurn': isClientTurn,
      'hostUserName': hostUserName,
      'clientUserName': clientUserName,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      board:
          (json['board'] as List).map((row) => List<String>.from(row)).toList(),
      hostLetters: List<String>.from(json['hostLetters']),
      clientLetters: List<String>.from(json['clientLetters']),
      bag: json['bag'] != null ? BagModel.fromJson(json['bag']) : null,
      hostScore: json['hostScore'] ?? 0,
      clientScore: json['clientScore'] ?? 0,
      isClientTurn: json['isClientTurn'] ?? false,
      hostUserName: json['hostUserName'] ?? 'Host',
      clientUserName: json['clientUserName'] ?? 'Client',
    );
  }

  String serialize() => jsonEncode(toJson());

  static GameState deserialize(String jsonStr) =>
      GameState.fromJson(jsonDecode(jsonStr));
}
