import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlarmSettingsProvider extends ChangeNotifier {
  static const String keyVolume = 'alarm_volume';
  static const String keySoundEnabled = 'alarm_sound_enabled';
  static const String keyVibrateEnabled = 'alarm_vibrate_enabled';
  static const String keyThreshold = 'alarm_threshold_minutes';

  double _volume = 0.8;
  bool _isSoundEnabled = true;
  bool _isVibrateEnabled = true;
  int _alarmThresholdMinutes = 3;

  // Getters
  double get volume => _volume;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isVibrateEnabled => _isVibrateEnabled;
  int get alarmThresholdMinutes => _alarmThresholdMinutes;

  /// Initialize and load settings
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _volume = prefs.getDouble(keyVolume) ?? 0.8;
    _isSoundEnabled = prefs.getBool(keySoundEnabled) ?? true;
    _isVibrateEnabled = prefs.getBool(keyVibrateEnabled) ?? true;
    _alarmThresholdMinutes = prefs.getInt(keyThreshold) ?? 3;
    notifyListeners();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyVolume, _volume);
    notifyListeners();
  }

  /// Toggle sound enabled
  Future<void> setSoundEnabled(bool value) async {
    _isSoundEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySoundEnabled, value);
    notifyListeners();
  }

  /// Toggle vibrate
  Future<void> setVibrateEnabled(bool value) async {
    _isVibrateEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVibrateEnabled, value);
    notifyListeners();
  }

  /// Set alarm threshold in minutes (1-10)
  Future<void> setAlarmThreshold(int minutes) async {
    _alarmThresholdMinutes = minutes.clamp(1, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyThreshold, _alarmThresholdMinutes);
    notifyListeners();
  }
}
