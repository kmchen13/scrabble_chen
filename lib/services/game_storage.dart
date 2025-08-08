import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> saveGameState(Map<String, dynamic> gameState) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastGameState', jsonEncode(gameState));
}

Future<String?> loadLastGameState() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('lastGameState'); // pas de jsonDecode ici
}

Future<void> clearLastGameState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('lastGameState');
}
