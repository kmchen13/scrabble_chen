import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'models/user_settings.dart';

class ParamScreen extends StatefulWidget {
  const ParamScreen({super.key});

  @override
  State<ParamScreen> createState() => _ParamScreenState();
}

class _ParamScreenState extends State<ParamScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _soundEnabled = true;
  String? _communicationMode; // nullable au départ pour indiquer chargement

  static const String settingsKey = 'user_settings';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(settingsKey);

    final settings =
        jsonString != null
            ? UserSettings.fromJson(json.decode(jsonString))
            : UserSettings.defaultSettings();

    setState(() {
      _nameController.text = settings.localUserName;
      // Protection : communicationMode doit être 'local' ou 'web', sinon 'local'
      _communicationMode =
          ['local', 'web'].contains(settings.communicationMode)
              ? settings.communicationMode
              : 'local';
      _soundEnabled = settings.soundEnabled;
    });
  }

  Future<void> _saveSettings() async {
    final settings = UserSettings(
      localUserName: _nameController.text,
      communicationMode: _communicationMode ?? 'local',
      soundEnabled: _soundEnabled,
    );

    if (!context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, json.encode(settings.toJson()));
    Navigator.pop(context); // Retour à l'écran précédent
  }

  @override
  Widget build(BuildContext context) {
    // Tant que les settings ne sont pas chargés, on affiche un indicateur
    if (_communicationMode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(flex: 1, child: Text("Nom du joueur :")),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: "Entrez votre nom",
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(flex: 1, child: Text("Mode de communication :")),
                Expanded(
                  flex: 2,
                  child: DropdownButton<String>(
                    value: _communicationMode,
                    isExpanded: true,
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _communicationMode = newValue;
                        });
                      }
                    },
                    items:
                        ['local', 'web'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'local'
                                  ? 'Local (Wi-Fi)'
                                  : 'En ligne (Web)',
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(flex: 1, child: Text("Sons activés :")),
                Expanded(
                  flex: 2,
                  child: Switch(
                    value: _soundEnabled,
                    onChanged: (value) {
                      setState(() {
                        _soundEnabled = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }
}
