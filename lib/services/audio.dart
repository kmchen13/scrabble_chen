import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
    try {
      await _player.play(AssetSource('sounds/notify.wav'));
    } catch (e) {
      print('Erreur lecture son : $e');
    }
  }
}
