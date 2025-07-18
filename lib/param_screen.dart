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
  final TextEditingController _localIPController = TextEditingController();
  final TextEditingController _localPortController = TextEditingController();
  final TextEditingController _udpPortController = TextEditingController();
  final TextEditingController _relayAddressController = TextEditingController();
  final TextEditingController _relayPortController = TextEditingController();

  bool _soundEnabled = true;
  String? _communicationMode;
  DateTime? _startTime;

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
      _localIPController.text = settings.localIP;
      _localPortController.text = settings.localPort.toString();
      _udpPortController.text = settings.udpPort.toString();
      _relayAddressController.text = settings.relayAddress;
      _relayPortController.text = settings.relayPort.toString();
      _communicationMode =
          ['local', 'web'].contains(settings.communicationMode)
              ? settings.communicationMode
              : 'local';
      _soundEnabled = settings.soundEnabled;
      _startTime = settings.startTime;
    });
  }

  Future<void> _saveSettings() async {
    final settings = UserSettings(
      localUserName: _nameController.text,
      communicationMode: _communicationMode ?? 'local',
      soundEnabled: _soundEnabled,
      localIP: _localIPController.text,
      localPort: int.tryParse(_localPortController.text) ?? 4567,
      udpPort: int.tryParse(_udpPortController.text) ?? 4560,
      expectedUserName: '',
      relayAddress: _relayAddressController.text,
      relayPort: int.tryParse(_relayPortController.text) ?? 8080,
    );

    if (!context.mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, json.encode(settings.toJson()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_communicationMode == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _buildTextField("Nom du joueur :", _nameController),
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
            _buildTextField(
              "Adresse IP locale :",
              _localIPController,
              enabled: false,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              "Port local :",
              _localPortController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              "Port UDP local :",
              _udpPortController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              "Adresse du relay :",
              _relayAddressController,
              enabled: false,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              "Port du relay :",
              _relayPortController,
              keyboardType: TextInputType.number,
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
            const SizedBox(height: 20),
            if (_startTime != null)
              Row(
                children: [
                  const Expanded(flex: 1, child: Text("Heure de début :")),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "${_startTime!.toLocal()}",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Row(
      children: [
        Expanded(flex: 1, child: Text(label)),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}
