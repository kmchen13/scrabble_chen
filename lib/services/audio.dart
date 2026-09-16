import 'package:audioplayers/audioplayers.dart';
import 'package:scrabble_P2P/services/settings_service.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  // Appelez cette fonction une seule fois (par exemple dans initState)
  Future<void> initAudioPlayer() async {
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          // 🔥 Supprimez la ligne audioFocus
          // audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {AVAudioSessionOptions.duckOthers},
        ),
      ),
    );
  }

  Future<void> playNotificationSound() async {
    await loadSettings();
    if (!settings.soundEnabled) {
      return;
    }
    try {
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (e) {
      print('Erreur lecture son : $e');
    }
  }
}
