import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'user_settings.dart'; // Assurez-vous que ce chemin est correct

/* Non utilisé*/

class SettingsNotifier extends ChangeNotifier {
  late UserSettings _settings;
  static const String settingsKey = 'user_settings';

  UserSettings get settings => _settings;

  // Charge les paramètres depuis SharedPreferences
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(settingsKey);
      if (jsonString != null) {
        _settings = UserSettings.fromJson(json.decode(jsonString));
      } else {
        _settings = UserSettings.defaultSettings();
      }
      notifyListeners(); // Notifier les écouteurs
    } catch (e) {
      print('Erreur lors du chargement des paramètres: $e');
    }
  }

  // Sauvegarde les paramètres dans SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, json.encode(_settings.toJson()));
    notifyListeners();
  }

  // Met à jour et sauvegarde les paramètres
  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    await save();
  }

  // Mise à jour individuelle des paramètres
  Future<void> updateLocalUserName(String name) async {
    _settings.localUserName = name;
    await save();
  }

  Future<void> updateCommunicationMode(String mode) async {
    _settings.communicationMode = mode;
    await save();
  }

  Future<void> updateSoundEnabled(bool enabled) async {
    _settings.soundEnabled = enabled;
    await save();
  }

  Future<void> updateLocalIP(String ip) async {
    _settings.localIP = ip;
    await save();
  }

  Future<void> updateLocalPort(int port) async {
    _settings.localPort = port;
    await save();
  }

  Future<void> updateUDPPort(int port) async {
    _settings.udpPort = port;
    await save();
  }

  Future<void> updateRelayAddress(String address) async {
    _settings.relayAddress = address;
    await save();
  }

  Future<void> updateRelayPort(int port) async {
    _settings.relayPort = port;
    await save();
  }

  Future<void> updateStartTime(DateTime? time) async {
    _settings.startTime = time;
    await save();
  }
}
