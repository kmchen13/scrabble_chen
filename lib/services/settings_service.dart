// services/settings_service.dart

import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/services/utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:scrabble_P2P/models/user_settings.dart';

UserSettings settings = UserSettings.defaultSettings();

const String initialUserName = String.fromEnvironment(
  'USER_NAME',
  defaultValue: '',
);

Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final key =
      initialUserName.isNotEmpty
          ? '${initialUserName}_settings'
          : 'user_settings';
  final jsonString = prefs.getString(key);

  if (jsonString != null) {
    settings = UserSettings.fromJson(json.decode(jsonString));
  } else {
    settings = UserSettings.defaultSettings(); // valeurs par défaut
  }
}

Future<void> saveSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final key =
      settings.localUserName.isNotEmpty
          ? '${settings.localUserName}_settings'
          : (initialUserName.isNotEmpty
              ? '${initialUserName}_settings'
              : 'user_settings');
  await prefs.setString(key, json.encode(settings.toJson()));
}
