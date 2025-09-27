// services/settings_service.dart

import 'package:scrabble_P2P/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:scrabble_P2P/models/user_settings.dart';
import 'package:scrabble_P2P/constants.dart';

UserSettings settings = UserSettings.defaultSettings();

const String initialUserName = String.fromEnvironment(
  'USER_NAME',
  defaultValue: '',
);

buildSettingsKey() {
  return initialUserName.isNotEmpty
      ? '${initialUserName}_settings'
      : 'user_settings';
}

Future<void> loadSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final key = buildSettingsKey();
  final jsonString = prefs.getString(key);

  if (jsonString != null) {
    settings = UserSettings.fromJson(json.decode(jsonString));
  } else {
    print(
      "Aucun réglage trouvé pour la clé $key, utilisation des valeurs par défaut.",
    );
    settings = UserSettings.defaultSettings(); // valeurs par défaut
  }
}

Future<void> saveSettings() async {
  if (debug) {
    print("Sauvegarde des réglages : ${settings.toJson()}");
  }
  final prefs = await SharedPreferences.getInstance();
  final key = buildSettingsKey();

  await prefs.setString(key, json.encode(settings.toJson()));
}
