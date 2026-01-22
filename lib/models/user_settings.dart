enum Language { fr, en, es }

extension LanguageX on Language {
  String get label {
    switch (this) {
      case Language.fr:
        return 'Français';
      case Language.en:
        return 'English';
      case Language.es:
        return 'Español';
    }
  }
}

Language languageFromString(String s) {
  switch (s) {
    case 'fr':
      return Language.fr;
    case 'en':
      return Language.en;
    case 'es':
      return Language.es;
    default:
      return Language.fr; // fallback
  }
}

String languageToString(Language l) {
  return l.name; // "fr", "en", "es"
}

class UserSettings {
  String localUserName;
  String language;
  String communicationMode;
  bool soundEnabled;
  String localIP;
  int localPort;
  int udpPort;
  String expectedUserName;
  String relayAddress;
  int relayPort;
  DateTime? startTime;
  int nameDisplayLimit;

  UserSettings({
    required this.localUserName,
    this.language = 'fr',
    required this.communicationMode,
    required this.soundEnabled,
    required this.localIP,
    required this.localPort,
    required this.udpPort,
    required this.expectedUserName,
    this.relayAddress = '',
    this.relayPort = 0,
    this.startTime,
    this.nameDisplayLimit = 5, // valeur par défaut
  });

  factory UserSettings.defaultSettings() {
    return UserSettings(
      localUserName: '',
      language: 'fr',
      communicationMode: 'local',
      soundEnabled: true,
      localIP: '',
      localPort: 4567,
      udpPort: 4560,
      expectedUserName: '',
      relayAddress: 'https://relay-server-3lv4.onrender.com',
      relayPort: 8080,
      startTime: null,
      nameDisplayLimit: 5,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localUserName': localUserName,
      'language': language,
      'communicationMode': communicationMode,
      'soundEnabled': soundEnabled,
      'localIP': localIP,
      'localPort': localPort,
      'udpPort': udpPort,
      'expectedUserName': expectedUserName,
      'relayAddress': relayAddress,
      'relayPort': relayPort,
      'startTime': startTime?.toIso8601String(),
      'nameDisplayLimit': nameDisplayLimit,
    };
  }

  String get relayServerUrl {
    if (relayPort == 0) {
      return "$relayAddress";
    } else {
      return "$relayAddress:$relayPort";
    }
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      localUserName: json['localUserName'] ?? '',
      language: json['language'] ?? 'fr',
      communicationMode: json['communicationMode'] ?? 'local',
      soundEnabled: json['soundEnabled'] ?? true,
      localIP: json['localIP'] ?? '',
      localPort: json['localPort'] ?? 4567,
      udpPort: json['udpPort'] ?? 4560,
      expectedUserName: json['expectedUserName'] ?? '',
      relayAddress: json['relayAddress'] ?? '',
      relayPort: json['relayPort'] ?? 0,
      startTime:
          json['startTime'] != null
              ? DateTime.tryParse(json['startTime'])
              : null,
      nameDisplayLimit: json['nameDisplayLimit'] ?? 5,
    );
  }

  // Méthode utilitaire pour copier l’objet avec une nouvelle startTime
  UserSettings copyWith({
    String? localUserName,
    String? language, // ✅ ajouter
    String? communicationMode,
    bool? soundEnabled,
    String? localIP,
    int? localPort,
    int? udpPort,
    String? expectedUserName,
    String? relayAddress,
    int? relayPort,
    DateTime? startTime,
    int? nameDisplayLimit, // ✅ garder
  }) {
    return UserSettings(
      localUserName: localUserName ?? this.localUserName,
      language: language ?? this.language, // ✅ utiliser
      communicationMode: communicationMode ?? this.communicationMode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      localIP: localIP ?? this.localIP,
      localPort: localPort ?? this.localPort,
      udpPort: udpPort ?? this.udpPort,
      expectedUserName: expectedUserName ?? this.expectedUserName,
      relayAddress: relayAddress ?? this.relayAddress,
      relayPort: relayPort ?? this.relayPort,
      startTime: startTime ?? this.startTime,
      nameDisplayLimit: nameDisplayLimit ?? this.nameDisplayLimit, // ✅ garder
    );
  }
}
