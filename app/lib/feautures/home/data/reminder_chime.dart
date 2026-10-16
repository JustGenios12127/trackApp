import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

class ReminderChime {
  ReminderChime._();

  static const _asset = 'notification/badumtss.mp3';
  static AudioPlayer? _player;
  static var _tuned = false;

  static Future<void> play() async {
    if (_underTest) return;
    try {
      final player = _player ??= AudioPlayer();
      if (!_tuned) {
        _tuned = true;
        try {
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setAudioContext(
            AudioContext(
              android: const AudioContextAndroid(
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.notification,
                audioFocus: AndroidAudioFocus.gainTransientMayDuck,
              ),
              iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
            ),
          );
        } catch (_) {}
      }
      try {
        await player.stop();
      } catch (_) {}
      await player.play(AssetSource(_asset), volume: 1);
    } catch (_) {}
  }

  static bool get _underTest {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }
}
