// models/user_settings.dart

class UserSettings {
  final String localUserName;
  final String communicationMode;
  final bool soundEnabled;

  UserSettings({
    required this.localUserName,
    required this.communicationMode,
    required this.soundEnabled,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      localUserName: json['localUserName'] ?? '',
      communicationMode: json['communicationMode'] ?? '',
      soundEnabled: json['soundEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'localUserName': localUserName,
      'communicationMode': communicationMode,
      'soundEnabled': soundEnabled,
    };
  }

  static UserSettings defaultSettings() {
    return UserSettings(
      localUserName: '',
      communicationMode: 'local',
      soundEnabled: true,
    );
  }
}
