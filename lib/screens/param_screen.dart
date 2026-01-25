import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrabble_P2P/constants.dart';
import 'package:scrabble_P2P/models/user_settings.dart';
import 'package:scrabble_P2P/services/settings_service.dart';
import 'package:scrabble_P2P/screens/home_screen.dart';
import 'package:scrabble_P2P/services/game_storage.dart';
import 'package:scrabble_P2P/services/dictionary.dart';

class ParamScreen extends StatefulWidget {
  const ParamScreen({super.key});

  @override
  State<ParamScreen> createState() => _ParamScreenState();
}

class _ParamScreenState extends State<ParamScreen> {
  static const String settingsKey = 'usersettings';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _localIPController = TextEditingController();
  final TextEditingController _localPortController = TextEditingController();
  final TextEditingController _udpPortController = TextEditingController();
  final TextEditingController _relayAddressController = TextEditingController();
  final TextEditingController _relayPortController = TextEditingController();
  final TextEditingController _nameLimitController = TextEditingController();
  int _nameDisplayLimit = 5; // valeur par défaut

  bool _soundEnabled = true;
  String? _communicationMode;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    // Charge les settings globaux
    await loadSettings();

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
      _nameDisplayLimit = settings.nameDisplayLimit;
      _nameLimitController.text = _nameDisplayLimit.toString();
    });
  }

  Future<void> _saveSettings() async {
    settings = UserSettings(
      localUserName: _nameController.text,
      language: settings.language,
      communicationMode: _communicationMode ?? 'local',
      soundEnabled: _soundEnabled,
      localIP: _localIPController.text,
      localPort: int.tryParse(_localPortController.text) ?? 4567,
      udpPort: int.tryParse(_udpPortController.text) ?? 4560,
      expectedUserName: '',
      relayAddress:
          _relayAddressController.text.isEmpty
              ? 'https://relay-server-eu.onrender.com'
              : _relayAddressController.text,
      relayPort:
          _relayPortController.text.isEmpty
              ? 0
              : int.tryParse(_relayPortController.text) ?? 0,
      nameDisplayLimit: int.tryParse(_nameLimitController.text) ?? 5,
    );

    await saveSettings();
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => HomeScreen()));
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(settingsKey);
    await loadSettings();
  }

  Future<void> _fetchDictionaryFromRelay(String language) async {
    // Exemple pour le relay server HTTP
    final uri = Uri.parse('${settings.relayAddress}/dictionary?lang=$language');

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      // Le serveur renvoie le dictionnaire en texte brut

      // Remplace le dictionnaire existant dans l'app
      final langEnum = ScrabbleLanguageX.fromString(settings.language);

      dictionaryService.replaceFromText(response.body, langEnum);
      dictionaryService.setLanguage(langEnum);
      if (debug)
        print(
          'Dictionnaire $language chargé avec ${dictionaryService.size} mots.',
        );
    } else {
      throw Exception(
        'Impossible de récupérer le dictionnaire du relay server',
      );
    }
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
            _buildTextField(
              "Nom du joueur :",
              _nameController,
              hintText: "Veuillez entrer votre pseudo",
            ),
            const SizedBox(height: 20),
            _buildLanguageSelector(),

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
                        ['local', 'web']
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value == 'local'
                                      ? 'Local (Wi-Fi)'
                                      : 'En ligne (Web)',
                                ),
                              ),
                            )
                            .toList(),
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
            _buildTextField("Adresse du relay :", _relayAddressController),
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
            _buildTextField(
              "Nombre de lettres affichées :",
              _nameLimitController,
              keyboardType: TextInputType.number,
              hintText: "Nombre de lettres à afficher dans le score",
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
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await clearSettings();
                await _initializeControllers();
              },
              child: const Text("Recharger les paramètres d'usine"),
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
    String hintText = '',
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
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              hintText: hintText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return FutureBuilder<bool>(
      future: gameStorage.isEmpty, // futur booléen
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final canChangeLanguage = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Dictionnaire :",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Language>(
              value: languageFromString(settings.language),
              items:
                  Language.values
                      .map(
                        (lang) => DropdownMenuItem(
                          value: lang,
                          child: Text(lang.label),
                        ),
                      )
                      .toList(),
              onChanged:
                  canChangeLanguage
                      ? (Language? newLang) async {
                        if (newLang == null) return;
                        final newLanguageStr = languageToString(newLang);

                        setState(() {
                          settings = settings.copyWith(
                            language: newLanguageStr,
                          );
                        });

                        // 🔹 Envoi au relay server pour récupérer le nouveau dictionnaire
                        try {
                          await _fetchDictionaryFromRelay(newLanguageStr);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Dictionnaire mis à jour pour $newLanguageStr',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Erreur lors du téléchargement du dictionnaire',
                              ),
                            ),
                          );
                        }
                      }
                      : null,

              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (!canChangeLanguage) ...[
              const SizedBox(height: 8),
              const Text(
                "La langue ne peut pas être modifiée tant que des parties sont enregistrées.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        );
      },
    );
  }
}
