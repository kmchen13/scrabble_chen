// services/settings_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:scrabble_P2P/models/user_settings.dart';

UserSettings settings = UserSettings.defaultSettings();

Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final jsonString = prefs.getString('user_settings');
  if (jsonString != null) {
    final jsonMap = Map<String, dynamic>.from(json.decode(jsonString));
    settings = UserSettings.fromJson(jsonMap);
  } else {
    settings = UserSettings.defaultSettings();
  }
}

Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_settings', json.encode(settings.toJson()));
}
