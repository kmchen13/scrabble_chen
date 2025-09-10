class UserSettings {
  String localUserName;
  String communicationMode;
  bool soundEnabled;
  String localIP;
  int localPort;
  int udpPort;
  String expectedUserName;
  String relayAddress;
  int relayPort;
  DateTime? startTime;

  UserSettings({
    required this.localUserName,
    required this.communicationMode,
    required this.soundEnabled,
    required this.localIP,
    required this.localPort,
    required this.udpPort,
    required this.expectedUserName,
    this.relayAddress = '',
    this.relayPort = 0,
    this.startTime,
  });

  factory UserSettings.defaultSettings() {
    return UserSettings(
      localUserName: '',
      communicationMode: 'local',
      soundEnabled: true,
      localIP: '',
      localPort: 4567,
      udpPort: 4560,
      expectedUserName: '',
      relayAddress: 'relay-server-3lv4.onrender.com',
      relayPort: 0,
      startTime: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localUserName': localUserName,
      'communicationMode': communicationMode,
      'soundEnabled': soundEnabled,
      'localIP': localIP,
      'localPort': localPort,
      'udpPort': udpPort,
      'expectedUserName': expectedUserName,
      'relayAddress': relayAddress,
      'relayPort': relayPort,
      'startTime': startTime?.toIso8601String(),
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
    );
  }

  // Méthode utilitaire pour copier l’objet avec une nouvelle startTime
  UserSettings copyWith({DateTime? startTime}) {
    return UserSettings(
      localUserName: localUserName,
      communicationMode: communicationMode,
      soundEnabled: soundEnabled,
      localIP: localIP,
      localPort: localPort,
      udpPort: udpPort,
      expectedUserName: expectedUserName,
      relayAddress: relayAddress,
      relayPort: relayPort,
      startTime: startTime ?? this.startTime,
    );
  }
}
