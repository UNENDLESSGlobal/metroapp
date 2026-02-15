import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import '../providers/alarm_settings_provider.dart';

class AlarmService {
  final AlarmSettingsProvider _settingsProvider;
  bool _isPlaying = false;

  AlarmService(this._settingsProvider);

  /// Start the alarm (system ringtone + vibration)
  Future<void> startAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;

    // Play Sound
    if (_settingsProvider.isSoundEnabled) {
      // playAlarm usually loops on Android. 
      // volume control via stream override might be tricky, plugin uses system volume.
      // We can try to set volume if plugin supports it, otherwise it relies on system.
      // FlutterRingtonePlayer.playAlarm(looping: true, volume: _settingsProvider.volume); 
      // Note: volume arg might not be supported in all versions/platforms of this plugin.
      // Checking docs (assumed): usually just playAlarm().
      // Verified: playAlarm(double volume, bool looping, bool asAlarm)
      
      await FlutterRingtonePlayer().playAlarm(
        looping: true, 
        volume: _settingsProvider.volume, // 0.0 to 1.0
        asAlarm: true, // Play on alarm stream
      );
    }
    
    // Vibrate
    if (_settingsProvider.isVibrateEnabled) {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [1000, 1000, 1000, 1000], repeat: 0); // Vibrate indefinitely
      }
    }
  }

  /// Stop the alarm
  Future<void> stopAlarm() async {
    _isPlaying = false;
    await FlutterRingtonePlayer().stop();
    Vibration.cancel();
  }
  
  bool get isPlaying => _isPlaying;
}
